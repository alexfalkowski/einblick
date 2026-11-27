function setupLogDetails(results) {
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

function setupActivitySelection(chart, selectRange) {
  const bars = [...chart.querySelectorAll(".activity-bar")];
  const tooltip = chart.parentElement.querySelector(".activity-tooltip");
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
    const range = `${bars[start].dataset.startLabel} – ${bars[end].dataset.endLabel} UTC`;
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
      showTooltip(last, bars[last].dataset.summary);
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
}

function setupLogActivity(panel, total, selectRange) {
  const status = panel.querySelector("#activity-status");
  const interval = panel.querySelector("#activity-interval");
  const snapshot = panel.querySelector("#activity-snapshot");
  const content = panel.querySelector("#activity-content");
  let activityURL;
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
    interval.textContent = "";
    snapshot.textContent = "";
    total.textContent = "";
    updateSnapshot();
    content.replaceChildren();
  }

  async function load(url) {
    reset(url);
    const request = new AbortController();
    pending = request;
    status.textContent = panel.dataset.loading;
    status.hidden = false;
    try {
      const response = await fetch(url, { signal: request.signal });
      if (!response.ok || response.headers.get("Einblick-View") !== "logs-activity") {
        throw new Error("Log activity unavailable");
      }
      const fragment = await response.text();
      if (request.signal.aborted) {
        return;
      }
      content.innerHTML = fragment;
      const summary = content.querySelector(".activity-summary");
      setupActivitySelection(summary.querySelector(".activity-bars"), (startTime, endTime) => selectRange(url, startTime, endTime));
      interval.textContent = summary.dataset.intervalLabel;
      snapshot.textContent = summary.dataset.throughLabel;
      total.textContent = summary.dataset.totalLabel;
      updateSnapshot();
      status.hidden = true;
    } catch {
      if (!request.signal.aborted) {
        status.textContent = panel.dataset.unavailable;
      }
    } finally {
      if (pending === request) {
        pending = undefined;
      }
    }
  }

  function keepSnapshotFor(url) {
    matchesResults = url === activityURL;
    updateSnapshot();
  }

  function cancelLoading() {
    if (pending) {
      pending.abort();
      pending = undefined;
      status.textContent = panel.dataset.unavailable;
    }
  }

  return { load, keepSnapshotFor, cancelLoading, clear: () => reset() };
}

function setupTimeFilters(form) {
  const timePresets = form.querySelectorAll(".time-presets button[name=window]");
  const currentRange = form.querySelector("#current-range");
  const customButton = form.querySelector("#custom-range");
  const customDates = form.querySelector("#custom-dates");
  const customMode = form.querySelector("#custom-mode");
  const startPicker = form.querySelector("#start-utc");
  const endPicker = form.querySelector("#end-utc");
  const earliestDate = form.querySelector("#earliest-date");
  const earliestDateTime = earliestDate.querySelector("time");
  const startTimeField = form.querySelector("#start-time");
  const endTimeField = form.querySelector("#end-time");
  const searchWindow = form.querySelector("#search-window");
  const searchButtons = form.querySelectorAll("[data-search-submit]");
  let pickerVersion = 0;

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
    const { startTime, endTime, earliest, recentWindow, custom } = bounds;
    startTimeField.value = startTime;
    endTimeField.value = endTime;

    // The pickers show UTC to the second. The hidden fields retain the exact timestamps.
    if (!preservePicker) {
      startPicker.value = startTime.slice(0, 19);
      endPicker.value = endTime.slice(0, 19);
    }
    earliestDate.hidden = !earliest;
    earliestDateTime.dateTime = earliest;
    earliestDateTime.textContent = earliest.slice(0, 19).replace("T", " ");
    searchWindow.value = recentWindow;
    customMode.value = custom === "true" ? "1" : "picker";
    showCustom(preservePicker || custom === "true", bounds);
  }

  customDates.addEventListener("input", () => { pickerVersion += 1; });
  customButton.addEventListener("click", () => {
    pickerVersion += 1;
    showCustom(true);
    startPicker.focus();
  });

  return { apply, isCustomOpen: () => !customDates.hidden, version: () => pickerVersion };
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
