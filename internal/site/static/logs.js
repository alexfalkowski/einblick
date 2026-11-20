const failure = document.querySelector("#query-failure");

if (failure) {
  const locationQuery = new URLSearchParams(location.search);
  const queryURL = document.querySelector("#results").dataset.queryUrl;
  if (queryURL && ["window", "start_utc", "end_utc"].some((name) => locationQuery.has(name))) {
    history.replaceState(history.state, "", queryURL);
  }

  const showFailure = (reason) => {
    failure.textContent = failure.dataset[reason];
    failure.hidden = false;
    document.querySelector("#results").hidden = true;
  };

  document.addEventListener("htmx:before:request", () => {
    failure.hidden = true;
  });

  document.addEventListener("htmx:after:request", (event) => {
    const { response, text } = event.detail.ctx;
    // Gateways can return HTML error pages. Only swap Einblick's fragment.
    const isLogFragment = response.headers.get("Einblick-View") === "logs-results" &&
      response.headers.get("Content-Type")?.startsWith("text/html") && text.trim();
    if (isLogFragment) {
      return;
    }

    event.preventDefault();
    const reason = { 499: "cancelled", 504: "timeout" }[response.status];
    showFailure(reason ?? "request");
  });

  document.addEventListener("htmx:error", (event) => {
    const reason = event.detail.ctx?.request.signal?.reason;
    showFailure(reason === "timeout" ? "timeout" : "request");
  });

  document.addEventListener("htmx:after:swap", () => {
    const { startTime, endTime } = document.querySelector("#results").dataset;
    if (startTime && endTime) {
      document.querySelector("#start-time").value = startTime;
      document.querySelector("#end-time").value = endTime;
      document.querySelector("#start-utc").value = startTime.slice(0, 19);
      document.querySelector("#end-utc").value = endTime.slice(0, 19);
    }
  });
}
