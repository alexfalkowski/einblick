function localizeLogTimes(results) {
  const times = results.querySelectorAll("time[data-display-time]");
  if (!times.length) {
    return;
  }
  const rowTime = new Intl.DateTimeFormat(results.lang, {
    ...calendarFields,
    ...clockFields,
    second: "2-digit",
  });
  const detailTime = detailTimeFormatter(results.lang);
  const timeZone = browserTimeZone();
  for (const time of times) {
    const rounded = time.dataset.displayTime;
    time.textContent = rounded
      ? exactLocalTime(detailTime, timeZone, rounded)
      : rowTime.format(logDate(time.dateTime));
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
    // Restore the inspector to its row before returning focus to the disclosure.
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

  closeButton.addEventListener("click", close);
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
