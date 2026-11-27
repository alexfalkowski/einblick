const calendarFields = { month: "short", day: "2-digit" };
const clockFields = { hour: "2-digit", minute: "2-digit", hourCycle: "h23" };

function logDate(value) {
  return new Date(value.replace(/\.(\d+)Z$/, (_, fraction) => `.${fraction.padEnd(3, "0").slice(0, 3)}Z`));
}

function detailTimeFormatter(language) {
  return new Intl.DateTimeFormat(language, {
    ...calendarFields, ...clockFields, year: "numeric", second: "2-digit",
    fractionalSecondDigits: 3, timeZoneName: "shortOffset",
  });
}

function exactLocalTime(formatter, timestamp) {
  // Intl formats milliseconds. Keep any additional digits from the original timestamp.
  const fraction = timestamp.match(/\.(\d+)Z$/)?.[1];
  return formatter.formatToParts(logDate(timestamp))
    .map(({ type, value }) => type === "fractionalSecond" && fraction ? fraction : value)
    .join("");
}

function localizeLogTimes(results) {
  const times = results.querySelectorAll("time[data-display-time]");
  if (!times.length) {
    return;
  }
  const rowTime = new Intl.DateTimeFormat(results.lang, {
    ...calendarFields, ...clockFields, second: "2-digit",
  });
  const detailTime = detailTimeFormatter(results.lang);
  for (const time of times) {
    const rounded = time.dataset.displayTime;
    time.textContent = rounded ? detailTime.format(logDate(rounded)) : rowTime.format(logDate(time.dateTime));
    time.title = exactLocalTime(detailTime, time.dateTime);
  }
  for (const time of results.querySelectorAll(".log-timing time")) {
    time.textContent = exactLocalTime(detailTime, time.dateTime);
  }
}

function setupLogDetails(results) {
  localizeLogTimes(results);
  const panel = results.querySelector(".log-details-panel");
  if (!panel?.showModal) {
    return;
  }

  const content = panel.querySelector(".log-details-content");
  const closeButton = panel.querySelector(".close-log-details");
  let selection;

  const close = (restoreFocus = true) => {
    if (!selection) {
      return;
    }

    const { disclosure, inlineCell, inspector } = selection;
    selection = undefined;
    disclosure.open = false;
    inlineCell.append(inspector);
    panel.close();
    if (restoreFocus) {
      disclosure.querySelector("summary").focus({ preventScroll: true });
    }
  };

  results.querySelector(".table-card").addEventListener("click", (event) => {
    const row = event.target.closest(".log-row");
    if (!row || event.defaultPrevented || event.button !== 0) {
      return;
    }

    event.preventDefault();
    if (document.getSelection()?.isCollapsed === false) {
      return;
    }
    const disclosure = row.querySelector(".log-disclosure");
    const inlineCell = row.nextElementSibling.cells[0];
    const inspector = inlineCell.querySelector(".inspector");
    selection = { disclosure, inlineCell, inspector };
    disclosure.open = true;
    content.append(inspector);
    panel.showModal();
    content.scrollTop = 0;
  });

  closeButton.addEventListener("click", () => close());
  panel.addEventListener("click", (event) => {
    if (event.target === panel && document.getSelection()?.isCollapsed !== false) {
      close();
    }
  });
  panel.addEventListener("cancel", (event) => {
    event.preventDefault();
    close();
  });
  results.dataset.drawer = "";

  return { close, isOpen: () => panel.open };
}

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
  const axisWithZone = new Intl.DateTimeFormat(summary.lang, {
    ...calendarFields, ...clock, timeZoneName: "shortOffset",
  });
  const day = new Intl.DateTimeFormat(summary.lang, { dateStyle: "short" });
  const round = (date) => Math.round(date.getTime() / precision) * precision;
  const sameDay = day.format(round(logDate(ticks[0].dateTime))) === day.format(round(logDate(lastTick.dateTime)));
  const tooltipTime = new Intl.DateTimeFormat(summary.lang, {
    ...(sameDay ? {} : calendarFields), ...clock, timeZoneName: "shortOffset",
  });
  const tooltipBounds = bars.map(({ dataset }) => ({
    start: tooltipTime.format(round(logDate(dataset.start))),
    end: tooltipTime.format(round(logDate(dataset.end))),
  }));
  const detailTime = detailTimeFormatter(summary.lang);
  for (const tick of ticks) {
    tick.textContent = (tick === lastTick ? axisWithZone : axis).format(logDate(tick.dateTime));
    tick.title = exactLocalTime(detailTime, tick.dateTime);
  }

  let first;
  const barAt = (clientX) => {
    const { left, width } = chart.getBoundingClientRect();
    const index = Math.floor((clientX - left) * bars.length / width);
    return Math.max(0, Math.min(index, bars.length - 1));
  };
  const selectThrough = (last) => {
    const start = Math.min(first, last);
    const end = Math.max(first, last);
    bars.forEach((bar, index) => bar.toggleAttribute("data-selected", index >= start && index <= end));
    const range = `${tooltipBounds[start].start} – ${tooltipBounds[end].end}`;
    showTooltip(last, `${tooltip.dataset.search} ${range}`);
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
      const { start, end } = tooltipBounds[last];
      const label = summary.dataset.bucketFormat
        .replace("{start}", start).replace("{end}", end).replace("{count}", bars[last].dataset.count);
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
  const status = panel.querySelector("#activity-status");
  const retry = panel.querySelector("#retry-activity");
  const interval = panel.querySelector("#activity-interval");
  const snapshot = panel.querySelector("#activity-snapshot");
  const content = panel.querySelector("#activity-content");
  let activityURL;
  let resultsURL;
  let matchesResults = true;
  let pending;

  function updateSnapshot() {
    snapshot.hidden = matchesResults || !snapshot.textContent;
    total.hidden = !matchesResults || !total.textContent;
  }

  function reset(url) {
    pending?.abort();
    pending = undefined;
    activityURL = url;
    matchesResults = true;
    panel.hidden = !url;
    status.hidden = true;
    retry.hidden = true;
    interval.textContent = "";
    snapshot.textContent = "";
    total.textContent = "";
    updateSnapshot();
    content.replaceChildren();
  }

  async function load(url) {
    resultsURL = url;
    reset(url);
    if (!url) {
      return;
    }
    const request = new AbortController();
    pending = request;
    status.textContent = panel.dataset.loading;
    status.hidden = false;
    try {
      const response = await fetch(url, { signal: request.signal });
      if (request.signal.aborted) {
        return;
      }
      if (!response.ok || response.headers.get("Einblick-View") !== "logs-activity") {
        const reason = response.status === 504 ? "timeout"
          : response.headers.get("Einblick-Activity") === "busy" ? "busy"
          : "unavailable";
        status.textContent = panel.dataset[reason];
        retry.hidden = !resultsURL || reason === "unavailable";
        return;
      }
      const fragment = await response.text();
      if (request.signal.aborted) {
        return;
      }
      content.innerHTML = fragment;
      const summary = content.querySelector(".activity-summary");
      snapshot.textContent = setupActivitySelection(summary, (startTime, endTime) => selectRange(url, startTime, endTime));
      interval.textContent = summary.dataset.intervalLabel;
      total.textContent = summary.dataset.totalLabel;
      updateSnapshot();
      status.hidden = true;
    } catch {
      if (!request.signal.aborted) {
        status.textContent = panel.dataset.unavailable;
        retry.hidden = !resultsURL;
      }
    } finally {
      if (pending === request) {
        pending = undefined;
      }
    }
  }

  function keepSnapshotFor(url) {
    resultsURL = url;
    matchesResults = url === activityURL;
    retry.hidden ||= !url;
    updateSnapshot();
  }

  function cancelLoading() {
    if (pending) {
      pending.abort();
      pending = undefined;
      status.textContent = panel.dataset.unavailable;
    }
  }

  retry.addEventListener("click", () => load(resultsURL));

  return { load, keepSnapshotFor, cancelLoading, clear: () => load() };
}

function localPickerValue(date) {
  const local = new Date(0);
  local.setUTCFullYear(date.getFullYear(), date.getMonth(), date.getDate());
  local.setUTCHours(date.getHours(), date.getMinutes(), date.getSeconds());
  return local.toISOString().slice(0, 19);
}

function utcPickerValue(value) {
  const seconds = value.length === 16 ? `${value}:00` : value;
  // Date chooses the earlier instant at a repeated local time and moves a skipped time forward.
  const date = new Date(seconds);
  return Number.isFinite(date.getTime()) && localPickerValue(date) === seconds ? date.toISOString().slice(0, 19) : "";
}

function setupTimeFilters(form) {
  const timePresets = form.querySelectorAll(".time-presets button[name=window]");
  const currentRange = form.querySelector("#current-range");
  const customButton = form.querySelector("#custom-range");
  const customDates = form.querySelector("#custom-dates");
  const customMode = form.querySelector("#custom-mode");
  const startPicker = form.querySelector("#start-utc");
  const endPicker = form.querySelector("#end-utc");
  const startError = form.querySelector("#start-date-error");
  const startTimeField = form.querySelector("#start-time");
  const endTimeField = form.querySelector("#end-time");
  const searchWindow = form.querySelector("#search-window");
  const searchButtons = form.querySelectorAll("[data-search-submit]");
  const zoneLabel = form.querySelector("#picker-time-zone");
  const pickerBounds = [[startPicker, startTimeField], [endPicker, endTimeField]].map(([picker, applied]) => ({
    picker, applied, label: picker.getAttribute("aria-label"),
  }));
  const language = form.closest("[lang]").lang;
  let formatter;
  let pickerVersion = 0;

  function renderPickers() {
    formatter = new Intl.DateTimeFormat(language, {
      ...calendarFields, ...clockFields, year: "numeric", second: "2-digit", timeZoneName: "shortOffset",
    });
    const timeZone = formatter.resolvedOptions().timeZone;
    zoneLabel.textContent = timeZone;
    for (const bound of pickerBounds) {
      const { picker, applied, label } = bound;
      picker.setAttribute("aria-label", label.replace("UTC", timeZone));
      bound.exact = applied.value;
      picker.value = localPickerValue(logDate(bound.exact));
      bound.renderedValue = picker.value;
      picker.setCustomValidity("");
    }
  }

  renderPickers();
  for (const bound of pickerBounds) {
    bound.picker.addEventListener("input", () => {
      const { picker, renderedValue } = bound;
      const skippedTime = picker.value && picker.value !== renderedValue && !utcPickerValue(picker.value);
      picker.setCustomValidity(skippedTime ? zoneLabel.dataset.invalidTime : "");
    });
  }
  form.addEventListener("formdata", ({ formData }) => {
    for (const { picker, exact, renderedValue } of pickerBounds) {
      if (formData.has(picker.name)) {
        // Untouched fields keep the UTC bounds used to render them, including fractional seconds.
        const utc = picker.value === renderedValue ? exact.slice(0, -1) : utcPickerValue(picker.value);
        formData.set(picker.name, utc);
      }
    }
  });

  function showCustom(custom, { window: selectedWindow, recentWindow } = {}) {
    customButton.setAttribute("aria-expanded", custom);
    customButton.setAttribute("aria-pressed", custom);
    customDates.hidden = !custom;
    for (const input of [customMode, startPicker, endPicker]) {
      input.disabled = !custom;
    }
    currentRange.hidden = custom || Boolean(selectedWindow);
    searchButtons.forEach((button) => { button.value = custom ? "" : recentWindow; });
    timePresets.forEach((preset) => { preset.setAttribute("aria-pressed", !custom && preset.value === selectedWindow); });
  }

  function apply(bounds, { preservePicker } = {}) {
    const { startTime, endTime, recentWindow, custom } = bounds;
    startTimeField.value = startTime;
    endTimeField.value = endTime;

    if (!preservePicker) {
      renderPickers();
      clearStartError();
    }
    searchWindow.value = recentWindow;
    customMode.value = custom === "true" ? "1" : "picker";
    showCustom(preservePicker || custom === "true", bounds);
  }

  function clearStartError() {
    startError.hidden = true;
    startError.textContent = "";
    startPicker.removeAttribute("aria-invalid");
  }

  function showStartError(cutoff) {
    const date = formatter.format(logDate(cutoff));
    startPicker.setAttribute("aria-invalid", "true");
    startError.textContent = startError.dataset.message.replace("{date}", date);
    startError.hidden = false;
    startPicker.focus();
  }

  startPicker.addEventListener("input", clearStartError);
  customDates.addEventListener("input", () => { pickerVersion += 1; });
  customButton.addEventListener("click", () => {
    pickerVersion += 1;
    showCustom(true);
    startPicker.focus();
  });

  return { apply, showStartError, isCustomOpen: () => !customDates.hidden, version: () => pickerVersion };
}

function setupMessageFilter(form) {
  const input = form.querySelector("#text");
  const clear = form.querySelector("#clear-message");
  const updateClearButton = () => { clear.hidden = !input.value; };

  input.addEventListener("input", updateClearButton);
  form.addEventListener("submit", (event) => {
    if (event.submitter?.name === "clear_message") {
      input.value = "";
      input.focus();
      updateClearButton();
    }
  });
  form.addEventListener("htmx:config:request", (event) => {
    // htmx disables the submit buttons before htmx:before:request.
    if (event.detail.ctx.sourceEvent?.submitter === document.activeElement) {
      input.focus();
    }
  });

  return input;
}

function setupLogSearch(form) {
  const failure = document.querySelector("#query-failure");
  const failureMessage = failure.querySelector("#query-failure-message");
  const retryButton = failure.querySelector("#retry-query");
  const refreshInterval = document.querySelector("#refresh-interval");
  const timeFilters = setupTimeFilters(form);
  const messageInput = setupMessageFilter(form);
  const activity = setupLogActivity(
    document.querySelector("#log-activity"),
    document.querySelector("#log-result-total"),
    openActivityRange,
  );

  let results = document.querySelector("#results");
  let details = setupLogDetails(results);
  let queryURL = results.dataset.queryUrl;
  let failedQuery;
  let manualQueryFailed = false;
  const requests = new WeakMap();

  function refreshPaused() {
    return details?.isOpen() || timeFilters.isCustomOpen();
  }

  function openActivityRange(activityURL, startTime, endTime) {
    const url = new URL(activityURL, location.href);
    url.pathname = new URL(form.action).pathname;
    url.searchParams.set("start_time", startTime);
    url.searchParams.set("end_time", endTime);
    url.searchParams.set("custom", "1");
    location.assign(url);
  }

  function showFailure(reason, ctx) {
    const refreshing = ctx?.sourceElement === refreshInterval;
    if (ctx?.sourceElement && !refreshing) {
      manualQueryFailed = true;
    }
    details?.close(false);
    failureMessage.textContent = failure.dataset[reason];
    failedQuery = undefined;
    if (ctx?.request.body) {
      const { method, action, body } = ctx.request;
      failedQuery = { method, action, source: ctx.sourceElement, values: Object.fromEntries(body) };
    }
    retryButton.hidden = !failedQuery;
    failure.hidden = false;
    results.hidden = true;
    if (refreshing) {
      activity.keepSnapshotFor();
    } else {
      activity.clear();
    }
  }

  function beforeRequest(event) {
    const { ctx } = event.detail;
    const paging = Boolean(ctx.sourceElement?.matches(".next"));
    // htmx replaces the pagination link before firing htmx:after:swap.
    requests.set(ctx, { paging, pickerVersion: timeFilters.version() });
    if (ctx.sourceElement !== refreshInterval && !paging) {
      activity.cancelLoading();
    }
    failedQuery = undefined;
    failure.hidden = true;
    const pagination = results.querySelector(".pagination");
    if (pagination) {
      if (pagination.contains(document.activeElement)) {
        messageInput.focus();
      }
      pagination.inert = true;
    }
  }

  function afterRequest(event) {
    const { ctx } = event.detail;
    if (ctx.sourceElement === refreshInterval && refreshPaused()) {
      event.preventDefault();
      return;
    }

    const { response, text } = ctx;
    // Gateways can return HTML error pages. Only swap Einblick's fragment.
    const isLogFragment = response.headers.get("Einblick-View") === "logs-results" &&
      response.headers.get("Content-Type")?.startsWith("text/html") && text.trim();
    if (isLogFragment) {
      if (ctx.sourceElement !== refreshInterval) {
        manualQueryFailed = response.status >= 400;
      }
      const earliestStart = response.headers.get("Einblick-Earliest-Start");
      if (earliestStart && timeFilters.isCustomOpen()) {
        event.preventDefault();
        if (requests.get(ctx)?.pickerVersion === timeFilters.version()) {
          timeFilters.showStartError(earliestStart);
        }
      }
      return;
    }

    event.preventDefault();
    const reason = { 499: "cancelled", 504: "timeout" }[response.status];
    showFailure(reason ?? "request", ctx);
  }

  function requestError(event) {
    const { ctx } = event.detail;
    if (ctx?.sourceElement === refreshInterval && refreshPaused()) {
      return;
    }
    showFailure(ctx?.request.signal?.reason === "timeout" ? "timeout" : "request", ctx);
  }

  function afterResultsSwap(event) {
    results = document.querySelector("#results");
    details = setupLogDetails(results);

    const { ctx } = event.detail;
    const refreshing = ctx?.sourceElement === refreshInterval;
    const request = requests.get(ctx);
    const keepsActivity = refreshing || request?.paging;
    const { queryUrl, activityUrl } = results.dataset;
    if (!queryUrl) {
      if (refreshing) {
        activity.keepSnapshotFor();
      } else {
        activity.clear();
      }
      return;
    }

    queryURL = queryUrl;
    const pickerChanged = request && request.pickerVersion !== timeFilters.version();
    const preservePicker = timeFilters.isCustomOpen() && (keepsActivity || pickerChanged);
    timeFilters.apply(results.dataset, { preservePicker });

    if (keepsActivity) {
      activity.keepSnapshotFor(activityUrl);
    } else {
      activity.load(activityUrl);
    }
  }

  if (queryURL !== location.pathname + location.search) {
    history.replaceState(history.state, "", queryURL + location.hash);
  }
  activity.load(results.dataset.activityUrl);

  const htmx = window.htmx;
  if (htmx) {
    let timer;
    refreshInterval.closest(".refresh-control").hidden = false;
    refreshInterval.addEventListener("change", () => {
      clearInterval(timer);
      const interval = htmx.parseInterval(refreshInterval.value);
      if (interval) {
        timer = setInterval(() => {
          if (!manualQueryFailed && !refreshPaused()) {
            htmx.ajax("PUT", queryURL, { source: refreshInterval });
          }
        }, interval);
      }
    });
    retryButton.addEventListener("click", () => {
      const { method, action, source, values } = failedQuery;
      htmx.ajax(method, action, { source, values });
    });
  }

  document.addEventListener("htmx:before:request", beforeRequest);
  document.addEventListener("htmx:finally:request", () => results.querySelector(".pagination")?.removeAttribute("inert"));
  document.addEventListener("htmx:before:history:update", (event) => {
    const { history: update, sourceElement } = event.detail;
    if (sourceElement === refreshInterval || update.path === location.pathname + location.search) {
      event.preventDefault();
    }
  });
  document.addEventListener("htmx:after:request", afterRequest);
  document.addEventListener("htmx:error", requestError);
  document.addEventListener("htmx:after:swap", afterResultsSwap);
}

const form = document.querySelector("#log-filters");
if (form) {
  setupLogSearch(form);
}
