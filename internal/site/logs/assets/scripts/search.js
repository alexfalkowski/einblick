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

  function beforeResultsSwap(event) {
    const request = requests.get(event.detail.ctx);
    if (request?.automatic) {
      request.scrollPosition = {
        pageY: window.scrollY,
        tableX: results.querySelector(".table-card")?.scrollLeft ?? 0,
      };
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
    const { scrollPosition } = request;
    if (scrollPosition) {
      const table = results.querySelector(".table-card");
      if (table) {
        table.scrollLeft = scrollPosition.tableX;
      }
      if (window.scrollY !== scrollPosition.pageY) {
        window.scrollTo({ top: scrollPosition.pageY, behavior: "instant" });
      }
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
  document.addEventListener("htmx:before:swap", beforeResultsSwap);
  document.addEventListener("htmx:after:swap", afterResultsSwap);
}

const form = document.querySelector("#log-filters");
if (form) {
  setupLogSearch(form);
}
