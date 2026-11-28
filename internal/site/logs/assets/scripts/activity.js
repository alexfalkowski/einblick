function setupActivitySelection(summary, selectRange) {
  const chart = summary.querySelector(".activity-bars");
  const bars = [...chart.querySelectorAll(".activity-bar")];
  const tooltip = chart.parentElement.querySelector(".activity-tooltip");
  const ticks = [...summary.querySelectorAll(".activity-axis time")];
  const lastTick = ticks.at(-1);
  const precision = Number(summary.dataset.tooltipPrecision);
  const clock = { ...clockFields };
  if (precision === 1000) {
    clock.second = "2-digit";
  }
  const axis = new Intl.DateTimeFormat(summary.lang, { ...calendarFields, ...clock });
  const day = new Intl.DateTimeFormat(summary.lang, { dateStyle: "short" });
  const round = (date) => {
    const rounded = new Date(Math.round(date.getTime() / precision) * precision);
    // Keep the original side of a clock change when rounding would cross it.
    return rounded.getTimezoneOffset() === date.getTimezoneOffset() ? rounded : date;
  };
  const sameDay = day.format(round(logDate(ticks[0].dateTime))) === day.format(round(logDate(lastTick.dateTime)));
  const tooltipTime = new Intl.DateTimeFormat(summary.lang, {
    ...(sameDay ? {} : calendarFields),
    ...clock,
  });
  const timeZone = browserTimeZone();

  function tooltipBoundary(timestamp) {
    const date = round(logDate(timestamp));
    return { time: tooltipTime.format(date), zone: timeZoneAt(timeZone, date) };
  }
  const tooltipBounds = bars.map(({ dataset }) => ({
    start: tooltipBoundary(dataset.start),
    end: tooltipBoundary(dataset.end),
  }));
  const detailTime = detailTimeFormatter(summary.lang);
  for (const tick of ticks) {
    tick.textContent = axis.format(logDate(tick.dateTime));
    tick.dataset.tooltip = exactLocalTime(detailTime, timeZone, tick.dateTime);
    tick.setAttribute("aria-label", tick.dataset.tooltip);
  }
  lastTick.textContent += ` ${timeZone.label}`;

  function tooltipRange(first, last) {
    const { start } = tooltipBounds[first];
    const { end } = tooltipBounds[last];
    return {
      start: start.zone === end.zone ? start.time : `${start.time} ${start.zone}`,
      end: `${end.time} ${end.zone}`,
    };
  }

  let first;
  const barAt = (clientX) => {
    // Pointer capture keeps delivering events outside the plot. Clamp to its end bars.
    const { left, width } = chart.getBoundingClientRect();
    const index = Math.floor((clientX - left) * bars.length / width);
    return Math.max(0, Math.min(index, bars.length - 1));
  };
  const selectThrough = (last) => {
    const start = Math.min(first, last);
    const end = Math.max(first, last);
    bars.forEach((bar, index) => bar.toggleAttribute("data-selected", index >= start && index <= end));
    const range = tooltipRange(start, end);
    showTooltip(last, `${tooltip.dataset.search} ${range.start} – ${range.end}`);
  };

  function showTooltip(index, text) {
    if (tooltip.textContent !== text) {
      tooltip.textContent = text;
    }
    tooltip.hidden = false;
    const width = chart.clientWidth;
    const center = width * (index + 0.5) / bars.length;
    const halfTooltip = tooltip.offsetWidth / 2;
    tooltip.style.left = Math.max(halfTooltip, Math.min(center, width - halfTooltip)) + "px";
  }

  chart.addEventListener("pointerdown", (event) => {
    if (!event.isPrimary || event.button !== 0) {
      return;
    }
    chart.setPointerCapture(event.pointerId);
    first = barAt(event.clientX);
    selectThrough(first);
  });
  chart.addEventListener("pointermove", (event) => {
    if (!event.isPrimary) {
      return;
    }
    const last = barAt(event.clientX);
    if (first === undefined) {
      const { start, end } = tooltipRange(last, last);
      const label = summary.dataset.bucketFormat
        .replace("{start}", start)
        .replace("{end}", end)
        .replace("{count}", bars[last].dataset.count);
      showTooltip(last, label);
    } else {
      selectThrough(last);
    }
  });
  chart.addEventListener("pointerleave", () => {
    if (first === undefined) {
      tooltip.hidden = true;
    }
  });
  chart.addEventListener("pointerup", (event) => {
    if (!event.isPrimary || first === undefined) {
      return;
    }
    const last = barAt(event.clientX);
    const startTime = bars[Math.min(first, last)].dataset.start;
    const endTime = bars[Math.max(first, last)].dataset.end;
    first = undefined;
    selectRange(startTime, endTime);
  });
  chart.addEventListener("lostpointercapture", () => {
    first = undefined;
    tooltip.hidden = true;
    bars.forEach((bar) => bar.removeAttribute("data-selected"));
  });

  return summary.dataset.throughFormat.replace("{end}", lastTick.textContent);
}

function setupLogActivity(panel, total, selectRange) {
  const feedback = panel.querySelector("#activity-feedback");
  const status = panel.querySelector("#activity-status");
  const retry = panel.querySelector("#retry-activity");
  const interval = panel.querySelector("#activity-interval");
  const snapshot = panel.querySelector("#activity-snapshot");
  const content = panel.querySelector("#activity-content");
  let resultsURL;
  let pending;
  let interrupted = false;

  function showCount(label) {
    if (total.textContent !== label) {
      total.textContent = label;
    }
    total.hidden = false;
  }

  function showPreviousSearch() {
    if (content.inert) {
      snapshot.textContent = panel.dataset.previous;
    }
  }

  function showFailure(reason, canRetry) {
    showPreviousSearch();
    showCount(total.dataset.unavailable);
    feedback.hidden = false;
    status.textContent = panel.dataset[reason];
    retry.hidden = !canRetry;
  }

  async function fetchSummary(url, signal) {
    try {
      const response = await fetch(url, { signal });
      if (!response.ok || response.headers.get("Einblick-View") !== "logs-activity") {
        const reason = response.status === 504 ? "timeout"
          : response.headers.get("Einblick-Activity") === "busy" ? "busy"
          : "unavailable";
        return { reason, canRetry: reason !== "unavailable" };
      }
      const template = document.createElement("template");
      template.innerHTML = await response.text();
      return { summary: template.content.querySelector(".activity-summary") };
    } catch {
      return { reason: "unavailable", canRetry: true };
    }
  }

  function prepare(url) {
    const controller = new AbortController();
    const request = { url, controller };
    request.ready = fetchSummary(url, controller.signal).then((outcome) => {
      request.outcome = outcome;
    });
    return request;
  }

  async function show(request) {
    cancelLoading();
    interrupted = false;
    resultsURL = request.url;
    feedback.hidden = true;
    status.textContent = "";
    panel.hidden = false;
    pending = request;
    // The previous chart can stay visible while a new search loads. Disable range selection until it matches.
    content.inert = !snapshot.hidden;
    content.setAttribute("aria-busy", "true");
    try {
      if (!request.outcome) {
        showCount(total.dataset.updating);
        showPreviousSearch();
        await request.ready;
      }
      if (request.controller.signal.aborted) {
        return;
      }
      const { summary, reason, canRetry } = request.outcome;
      if (reason) {
        showFailure(reason, canRetry);
        return;
      }
      snapshot.textContent = setupActivitySelection(summary, (startTime, endTime) => {
        selectRange(request.url, startTime, endTime);
      });
      snapshot.hidden = false;
      interval.textContent = summary.dataset.intervalLabel;
      interval.title = summary.dataset.intervalLabel;
      showCount(summary.dataset.totalLabel);
      content.replaceChildren(summary);
      content.inert = false;
    } catch {
      showFailure("unavailable", true);
    } finally {
      if (pending === request) {
        pending = undefined;
        content.removeAttribute("aria-busy");
      }
    }
  }

  function load(url) {
    show(prepare(url));
  }

  function cancelLoading() {
    if (pending) {
      pending.controller.abort();
      pending = undefined;
      content.removeAttribute("aria-busy");
      interrupted = true;
    }
  }

  function resumeLoading() {
    if (interrupted) {
      load(resultsURL);
    }
  }

  retry.addEventListener("click", () => load(resultsURL));

  return {
    load,
    prepare,
    show,
    cancelLoading,
    resumeLoading,
    isLoading: () => Boolean(pending),
  };
}
