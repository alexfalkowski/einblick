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
