const calendarFields = { month: "short", day: "2-digit" };
const clockFields = { hour: "2-digit", minute: "2-digit", hourCycle: "h23" };
const utcOffsetFormatter = new Intl.DateTimeFormat("en", { timeZoneName: "longOffset" });
const searchFeedbackDelay = 300;

function logDate(value) {
  // Normalize RFC 3339 fractions to the three digits used by Date.
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
    ...calendarFields,
    ...clockFields,
    year: "numeric",
    second: "2-digit",
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
