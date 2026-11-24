function setupLogDetails() {
  const panel = document.querySelector(".log-details-panel");
  if (!panel?.showModal) {
    return;
  }

  const results = panel.parentElement;
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

  return close;
}

const failure = document.querySelector("#query-failure");

if (failure) {
  let closeLogDetails = setupLogDetails();
  let failedQuery;

  const timePresets = document.querySelectorAll(".time-presets button");
  const currentRange = document.querySelector("#current-range");
  const failureMessage = document.querySelector("#query-failure-message");
  const retryButton = document.querySelector("#retry-query");
  const filters = document.querySelector("#log-filters");
  const searchButtons = filters.querySelectorAll("[data-search-submit]");
  const searchWindow = filters.querySelector("#search-window");
  const messageInput = document.querySelector("#text");
  const clearMessage = document.querySelector("#clear-message");
  const updateClearMessage = () => { clearMessage.hidden = !messageInput.value; };
  messageInput.addEventListener("input", updateClearMessage);
  filters.addEventListener("submit", (event) => {
    if (event.submitter?.name === "clear_message") {
      messageInput.value = "";
      messageInput.focus();
      updateClearMessage();
    }
  });
  filters.addEventListener("htmx:config:request", (event) => {
    // htmx disables the submit buttons before htmx:before:request.
    if (event.detail.ctx.sourceEvent.submitter === document.activeElement) {
      messageInput.focus();
    }
  });

  const locationQuery = new URLSearchParams(location.search);
  const queryURL = document.querySelector("#results").dataset.queryUrl;
  if (queryURL && ["window", "search_window", "start_utc", "end_utc", "clear_message"].some((name) => locationQuery.has(name))) {
    history.replaceState(history.state, "", queryURL);
  }

  retryButton.addEventListener("click", () => {
    const { method, action, source, values } = failedQuery;
    htmx.ajax(method, action, { source, values });
  });

  const showFailure = (reason, ctx) => {
    closeLogDetails?.(false);
    failureMessage.textContent = failure.dataset[reason];
    failedQuery = undefined;
    if (ctx?.request.body) {
      const { method, action, body } = ctx.request;
      failedQuery = { method, action, source: ctx.sourceElement, values: Object.fromEntries(body) };
    }
    retryButton.hidden = !failedQuery;
    failure.hidden = false;
    document.querySelector("#results").hidden = true;
  };

  document.addEventListener("htmx:before:request", () => {
    failedQuery = undefined;
    failure.hidden = true;
    const pagination = document.querySelector(".pagination");
    if (pagination) {
      if (pagination.contains(document.activeElement)) {
        messageInput.focus();
      }
      pagination.inert = true;
    }
  });

  document.addEventListener("htmx:finally:request", () => {
    document.querySelector(".pagination")?.removeAttribute("inert");
  });

  document.addEventListener("htmx:after:request", (event) => {
    const { ctx } = event.detail;
    const { response, text } = ctx;
    // Gateways can return HTML error pages. Only swap Einblick's fragment.
    const isLogFragment = response.headers.get("Einblick-View") === "logs-results" &&
      response.headers.get("Content-Type")?.startsWith("text/html") && text.trim();
    if (isLogFragment) {
      return;
    }

    event.preventDefault();
    const reason = { 499: "cancelled", 504: "timeout" }[response.status];
    showFailure(reason ?? "request", ctx);
  });

  document.addEventListener("htmx:error", (event) => {
    const { ctx } = event.detail;
    const reason = ctx?.request.signal?.reason;
    showFailure(reason === "timeout" ? "timeout" : "request", ctx);
  });

  document.addEventListener("htmx:after:swap", () => {
    closeLogDetails = setupLogDetails();
    const { startTime, endTime, window, recentWindow } = document.querySelector("#results").dataset;
    if (startTime && endTime) {
      document.querySelector("#start-time").value = startTime;
      document.querySelector("#end-time").value = endTime;
      searchWindow.value = recentWindow;
      searchButtons.forEach((button) => { button.value = recentWindow; });
      currentRange.hidden = Boolean(window);
      timePresets.forEach((preset) => preset.setAttribute("aria-pressed", preset.value === window));
    }
  });
}
