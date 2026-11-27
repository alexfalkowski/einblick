const calendarFields = { month: "short", day: "2-digit" };
const clockFields = { hour: "2-digit", minute: "2-digit", hourCycle: "h23" };
const utcOffsetFormatter = new Intl.DateTimeFormat("en", { timeZoneName: "longOffset" });
const searchFeedbackDelay = 300;

function logDate(value) {
  return new Date(value.replace(/\.(\d+)Z$/, (_, fraction) => `.${fraction.padEnd(3, "0").slice(0, 3)}Z`));
}

function utcOffset(date) {
  const offset = utcOffsetFormatter.formatToParts(date).find(({ type }) => type === "timeZoneName").value;
  return offset === "GMT" ? "UTC+00:00" : offset.replace("GMT", "UTC");
}

function browserTimeZone() {
  const id = utcOffsetFormatter.resolvedOptions().timeZone;
  const fixed = id === "UTC" || id === "GMT" || id.startsWith("Etc/");
  const label = fixed
    ? utcOffset(new Date()).replace("UTC+00:00", "UTC")
    : id.split("/").at(-1).replaceAll("_", " ");
  return { id, label, fixed };
}

function timeZoneAt(timeZone, date) {
  return timeZone.fixed ? timeZone.label : `${timeZone.label} (${utcOffset(date)})`;
}

function detailTimeFormatter(language) {
  return new Intl.DateTimeFormat(language, {
    ...calendarFields, ...clockFields, year: "numeric", second: "2-digit",
    fractionalSecondDigits: 3,
  });
}

function exactLocalTime(formatter, timeZone, timestamp) {
  // Intl formats milliseconds. Keep any additional digits from the original timestamp.
  const fraction = timestamp.match(/\.(\d+)Z$/)?.[1];
  const date = logDate(timestamp);
  const time = formatter.formatToParts(date)
    .map(({ type, value }) => type === "fractionalSecond" && fraction ? fraction : value)
    .join("");
  return `${time} ${timeZoneAt(timeZone, date)}`;
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
  const timeZone = browserTimeZone();
  for (const time of times) {
    const rounded = time.dataset.displayTime;
    time.textContent = rounded ? exactLocalTime(detailTime, timeZone, rounded) : rowTime.format(logDate(time.dateTime));
    time.title = exactLocalTime(detailTime, timeZone, time.dateTime);
  }
  for (const time of results.querySelectorAll(".log-timing time")) {
    time.textContent = exactLocalTime(detailTime, timeZone, time.dateTime);
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

  const close = () => {
    if (!selection) {
      return;
    }

    const { disclosure, inlineCell, inspector } = selection;
    selection = undefined;
    disclosure.open = false;
    inlineCell.append(inspector);
    panel.close();
    disclosure.querySelector("summary").focus({ preventScroll: true });
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

  return panel;
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
  const day = new Intl.DateTimeFormat(summary.lang, { dateStyle: "short" });
  const round = (date) => {
    const rounded = new Date(Math.round(date.getTime() / precision) * precision);
    // Keep the original side of a clock change when rounding would cross it.
    return rounded.getTimezoneOffset() === date.getTimezoneOffset() ? rounded : date;
  };
  const sameDay = day.format(round(logDate(ticks[0].dateTime))) === day.format(round(logDate(lastTick.dateTime)));
  const tooltipTime = new Intl.DateTimeFormat(summary.lang, {
    ...(sameDay ? {} : calendarFields), ...clock,
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
    request.ready = fetchSummary(url, controller.signal).then((outcome) => { request.outcome = outcome; });
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
      snapshot.textContent = setupActivitySelection(summary, (startTime, endTime) => selectRange(request.url, startTime, endTime));
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

  return { load, prepare, show, cancelLoading, resumeLoading, isLoading: () => Boolean(pending) };
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
    picker, applied,
  }));
  const language = form.closest("[lang]").lang;
  const formatter = new Intl.DateTimeFormat(language, {
    ...calendarFields, ...clockFields, year: "numeric", second: "2-digit",
  });
  const timeZone = browserTimeZone();
  zoneLabel.textContent = timeZone.label;
  let pickerVersion = 0;

  function renderPickers() {
    for (const bound of pickerBounds) {
      const { picker, applied } = bound;
      bound.exact = applied.value;
      picker.value = localPickerValue(logDate(bound.exact));
      bound.renderedValue = picker.value;
      picker.setCustomValidity("");
    }
  }

  renderPickers();
  for (const bound of pickerBounds) {
    const label = bound.picker.getAttribute("aria-label");
    bound.picker.setAttribute("aria-label", label.replace("UTC", timeZone.id));
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
    zoneLabel.hidden = !custom;
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
    const date = logDate(cutoff);
    const cutoffTime = `${formatter.format(date)} ${timeZoneAt(timeZone, date)}`;
    startPicker.setAttribute("aria-invalid", "true");
    startError.textContent = startError.dataset.message.replace("{date}", cutoffTime);
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
}

function setupLogSearch(form) {
  const progress = document.querySelector("#query-progress");
  const failure = document.querySelector("#query-failure");
  const failureMessage = failure.querySelector("#query-failure-message");
  const retryButton = failure.querySelector("#retry-query");
  const refreshInterval = document.querySelector("#refresh-interval");
  const timeFilters = setupTimeFilters(form);
  setupMessageFilter(form);
  const activity = setupLogActivity(
    document.querySelector("#log-activity"),
    document.querySelector("#log-result-total"),
    openActivityRange,
  );

  let results = document.querySelector("#results");
  let details = setupLogDetails(results);
  let queryURL = results.dataset.queryUrl;
  let activeRequest;
  let latestSearch;
  let progressTimer;
  let failedQuery;
  let manualQueryFailed = false;
  let refreshVersion = 0;
  const requests = new WeakMap();

  function refreshPaused() {
    return details?.open || results.contains(document.activeElement) || timeFilters.isCustomOpen();
  }

  function openActivityRange(activityURL, startTime, endTime) {
    const url = new URL(activityURL, location.href);
    url.pathname = new URL(form.action).pathname;
    url.searchParams.set("start_time", startTime);
    url.searchParams.set("end_time", endTime);
    url.searchParams.set("custom", "1");
    location.assign(url);
  }

  function clearFailure() {
    if (document.activeElement === retryButton) {
      form.querySelector("button[data-search-submit]").focus({ preventScroll: true });
    }
    failedQuery = undefined;
    failure.hidden = true;
    failureMessage.textContent = "";
  }

  function showFailure(message, ctx, request) {
    if (!request.automatic) {
      manualQueryFailed = true;
    }
    const { method, action, body } = ctx.request;
    const { paging, refreshing, pickerVersion } = request;
    failedQuery = { method, action, values: Object.fromEntries(body), paging, refreshing, pickerVersion };
    progress.textContent = "";
    failure.hidden = false;
    if (failureMessage.textContent !== message) {
      failureMessage.textContent = message;
    }
  }

  function configureRequest(event) {
    const { ctx } = event.detail;
    const { sourceElement, logRetry } = ctx;
    const automatic = sourceElement === refreshInterval;
    const paging = logRetry?.paging ?? sourceElement.matches(".next");
    if (sourceElement !== form && !automatic && !paging && !logRetry) {
      return;
    }

    requests.set(ctx, {
      automatic, paging, refreshing: automatic || logRetry?.refreshing,
      refreshVersion, pickerVersion: logRetry?.pickerVersion ?? timeFilters.version(),
    });
    if (!automatic) {
      latestSearch = ctx;
      requests.get(activeRequest)?.activity?.controller.abort();
      clearFailure();
      progressTimer ??= setTimeout(() => { progress.textContent = progress.dataset.message; }, searchFeedbackDelay);
    }
  }

  function beforeRequest(event) {
    const { ctx } = event.detail;
    const request = requests.get(ctx);
    if (!request) {
      return;
    }
    activeRequest = ctx;
    // A queued submission can start after the original target was replaced.
    ctx.target = results;
    request.restorePageFocus = request.paging && document.activeElement === ctx.sourceElement;
    if (!request.paging) {
      activity.cancelLoading();
      const fetchResults = ctx.fetch;
      ctx.fetch = async (target, options) => {
        const response = await fetchResults(target, options);
        await prepareActivity(ctx, request, response);
        return response;
      };
    }
  }

  function isSuperseded(ctx, request) {
    if (request.automatic) {
      return Boolean(latestSearch) || request.refreshVersion !== refreshVersion || refreshPaused();
    }
    return latestSearch !== ctx;
  }

  function isLogFragment(response) {
    return response.headers.get("Einblick-View") === "logs-results" &&
      response.headers.get("Content-Type")?.startsWith("text/html");
  }

  async function prepareActivity(ctx, request, response) {
    if (!response.ok || !isLogFragment(response) || isSuperseded(ctx, request)) {
      return;
    }
    const template = document.createElement("template");
    template.innerHTML = await response.clone().text();
    const url = template.content.querySelector("#results")?.dataset.activityUrl;
    if (!url || isSuperseded(ctx, request)) {
      return;
    }

    // Keep the displayed rows and count together during a quick activity request.
    const prepared = activity.prepare(url);
    request.activity = prepared;
    await new Promise((resolve) => {
      const timer = setTimeout(resolve, searchFeedbackDelay);
      prepared.ready.then(() => {
        clearTimeout(timer);
        resolve();
      });
    });
  }

  function afterRequest(event) {
    const { ctx } = event.detail;
    const request = requests.get(ctx);
    if (!request) {
      return;
    }
    if (isSuperseded(ctx, request)) {
      event.preventDefault();
      return;
    }

    const { response, text } = ctx;
    // Gateways can return HTML error pages. Only swap Einblick's fragment.
    const hasFragment = isLogFragment(response) && text.trim();
    if (hasFragment && response.status < 400) {
      return;
    }

    event.preventDefault();
    const earliestStart = response.headers.get("Einblick-Earliest-Start");
    if (earliestStart && timeFilters.isCustomOpen()) {
      manualQueryFailed = true;
      if (request.pickerVersion === timeFilters.version()) {
        timeFilters.showStartError(earliestStart);
      }
      return;
    }

    const reason = { 499: "cancelled", 504: "timeout" }[response.status];
    const fragment = hasFragment && reason !== "timeout" ? new DOMParser().parseFromString(text, "text/html") : undefined;
    const message = fragment?.querySelector(".query-alert[role=alert] > p")?.textContent;
    showFailure(message || failure.dataset[reason ?? "request"], ctx, request);
  }

  function requestError(event) {
    const { ctx } = event.detail;
    const request = requests.get(ctx);
    if (!request || isSuperseded(ctx, request)) {
      return;
    }
    const reason = ctx.request.signal.reason === "timeout" ? "timeout" : "request";
    showFailure(failure.dataset[reason], ctx, request);
  }

  function finishRequest(event) {
    const { ctx } = event.detail;
    if (activeRequest !== ctx) {
      return;
    }
    requests.get(ctx)?.activity?.controller.abort();
    activeRequest = undefined;
    if (latestSearch === ctx) {
      latestSearch = undefined;
      clearTimeout(progressTimer);
      progressTimer = undefined;
      progress.textContent = "";
    }
    if (!latestSearch) {
      activity.resumeLoading();
    }
  }

  function afterResultsSwap(event) {
    const request = requests.get(event.detail.ctx);
    if (!request) {
      return;
    }
    results = document.querySelector("#results");
    details = setupLogDetails(results);
    clearFailure();
    if (!request.automatic) {
      manualQueryFailed = false;
    }

    const { queryUrl, activityUrl } = results.dataset;
    queryURL = queryUrl;
    const preserveAppliedPicker = request.refreshing || request.paging;
    const pickerChanged = request.pickerVersion !== timeFilters.version();
    const preservePicker = timeFilters.isCustomOpen() && (preserveAppliedPicker || pickerChanged);
    timeFilters.apply(results.dataset, { preservePicker });

    if (!request.paging) {
      const prepared = request.activity ?? activity.prepare(activityUrl);
      request.activity = undefined;
      activity.show(prepared);
    }
    if (request.restorePageFocus && document.activeElement === document.body) {
      results.querySelector(".table-card")?.focus({ preventScroll: true });
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
      refreshVersion += 1;
      const request = requests.get(activeRequest);
      if (request?.automatic) {
        request.activity?.controller.abort();
      }
      clearInterval(timer);
      const interval = htmx.parseInterval(refreshInterval.value);
      if (interval) {
        timer = setInterval(() => {
          if (!activeRequest && !latestSearch && !manualQueryFailed && !refreshPaused() && !activity.isLoading()) {
            htmx.ajax("PUT", queryURL, { source: refreshInterval });
          }
        }, interval);
      }
    });
    retryButton.addEventListener("click", () => {
      const { method, action, values, ...logRetry } = failedQuery;
      htmx.ajax(method, action, { source: retryButton, values, logRetry });
    });
  }

  document.addEventListener("htmx:config:request", configureRequest);
  document.addEventListener("htmx:before:request", beforeRequest);
  document.addEventListener("htmx:finally:request", finishRequest);
  document.addEventListener("htmx:before:history:update", (event) => {
    const { history: update } = event.detail;
    if (requests.get(activeRequest)?.refreshing || update.path === location.pathname + location.search) {
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
