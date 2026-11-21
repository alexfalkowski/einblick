package controller

import (
	"encoding/base64"
	"encoding/hex"
	"math"
	"strconv"

	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/model"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	logs "go.opentelemetry.io/proto/otlp/logs/v1"
)

const (
	hoursPerDay              = 24
	requestDurationPrecision = 2
)

var resourceLabels = map[string]string{
	"service.name":                "logs.service",
	"service.version":             "logs.service_version",
	"service.instance.id":         "logs.instance_id",
	"host.id":                     "logs.host_id",
	"deployment.environment.name": "logs.environment",
}

func logDetails(stored *storage.Log, entry *logs.LogRecord, source *logs.ResourceLogs, scope *logs.ScopeLogs) model.LogDetails {
	return model.LogDetails{
		Body:              logValue(entry.GetBody()),
		Attributes:        logFields(entry.GetAttributes()),
		Resource:          resourceFields(source),
		Scope:             scopeFields(scope),
		Environment:       stringAttribute(source.GetResource().GetAttributes(), "deployment.environment.name"),
		Request:           requestDetails(entry.GetAttributes()),
		Timing:            logTiming(stored.EventTime, stored.ReceiveTime, entry),
		SpanID:            hex.EncodeToString(entry.GetSpanId()),
		EventName:         entry.GetEventName(),
		DroppedAttributes: entry.GetDroppedAttributesCount(),
		Flags:             entry.GetFlags(),
	}
}

func logTiming(event, received time.Time, entry *logs.LogRecord) model.LogTiming {
	timing := model.LogTiming{ReceivedAt: received.UTC()}
	if observed := entry.GetObservedTimeUnixNano(); observed != 0 {
		// Split the unsigned value before converting to preserve times after 2262.
		//nolint:gosec // Each quotient and remainder fits in int64.
		timing.ObservedAt = time.Unix(int64(observed / uint64(time.Second))).Add(time.Duration(observed % uint64(time.Second)).Duration()).UTC()
	}

	switch {
	case entry.GetTimeUnixNano() != 0:
		timing.EventTimeLabel = "logs.timestamp"
	case !timing.ObservedAt.IsZero():
		timing.EventTimeLabel = "logs.observed"
	default:
		timing.EventTimeLabel = "logs.received"
		return timing
	}

	timing.ReceiptOffset, timing.ReceiptLabel = receiptOffset(event, timing.ReceivedAt)
	return timing
}

func receiptOffset(event, received time.Time) (string, string) {
	if event.Equal(received) {
		return strings.Empty, "logs.received_same"
	}

	// A time.Duration saturates for part of the supported OTLP timestamp range.
	seconds := float64(received.Unix()-event.Unix()) + float64(received.Nanosecond()-event.Nanosecond())/float64(time.Second)
	label := "logs.received_later"
	if received.Before(event) {
		label = "logs.received_earlier"
	}
	return durationText(math.Abs(seconds), 0), label
}

func requestDetails(attributes []*common.KeyValue) model.RequestDetails {
	var details model.RequestDetails
	switch stringAttribute(attributes, "system") {
	case "http":
		details.StatusLabel = "logs.http_status"
		for _, attribute := range attributes {
			if code, ok := attribute.GetValue().GetValue().(*common.AnyValue_IntValue); attribute.GetKey() == "code" && ok {
				details.Status = strconv.FormatInt(code.IntValue, 10)
				break
			}
		}
	case "grpc":
		details.StatusLabel = "logs.grpc_status"
		details.Status = stringAttribute(attributes, "code")
	default:
		return details
	}

	if elapsed, err := time.ParseDuration(stringAttribute(attributes, "duration")); err == nil && elapsed >= 0 {
		details.Duration = durationText(elapsed.Duration().Seconds(), requestDurationPrecision)
	}
	return details
}

func durationText(seconds float64, precision int) string {
	minute, hour := time.Minute.Duration().Seconds(), time.Hour.Duration().Seconds()
	day := hoursPerDay * hour

	var (
		value float64
		unit  string
	)
	switch {
	case seconds >= day:
		value, unit = seconds/day, "d"
	case seconds >= hour:
		value, unit = seconds/hour, "h"
	case seconds >= minute:
		value, unit = seconds/minute, "min"
	case seconds < 1:
		value, unit = seconds/time.Millisecond.Duration().Seconds(), "ms"
	default:
		value, unit = seconds, "s"
	}
	if value > 0 && value < 1 && unit == "ms" {
		return "<1 ms"
	}
	return strings.Concat(strconv.FormatFloat(value, 'f', precision, 64), " ", unit)
}

func logFields(attributes []*common.KeyValue) []model.LogField {
	fields := make([]model.LogField, 0, len(attributes))
	for _, attribute := range attributes {
		name := attribute.GetKey()
		if strings.IsEmpty(name) && attribute.GetKeyStrindex() != 0 {
			name = "#" + strconv.FormatInt(int64(attribute.GetKeyStrindex()), 10)
		}
		fields = append(fields, model.LogField{Name: name, Value: logValue(attribute.GetValue())})
	}
	return fields
}

func logValue(value *common.AnyValue) model.LogValue {
	switch typed := value.GetValue().(type) {
	case *common.AnyValue_StringValue:
		return logString(typed.StringValue)
	case *common.AnyValue_BoolValue:
		return model.LogValue{Text: strconv.FormatBool(typed.BoolValue)}
	case *common.AnyValue_IntValue:
		return model.LogValue{Text: strconv.FormatInt(typed.IntValue, 10)}
	case *common.AnyValue_DoubleValue:
		return model.LogValue{Text: strconv.FormatFloat(typed.DoubleValue, 'g', -1, 64)}
	case *common.AnyValue_BytesValue:
		return model.LogValue{Text: base64.StdEncoding.EncodeToString(typed.BytesValue), Label: "logs.bytes"}
	case *common.AnyValue_StringValueStrindex:
		return model.LogValue{Text: strconv.FormatInt(int64(typed.StringValueStrindex), 10), Label: "logs.string_index"}
	case *common.AnyValue_ArrayValue:
		return logList(typed.ArrayValue.GetValues())
	case *common.AnyValue_KvlistValue:
		return model.LogValue{Fields: logFields(typed.KvlistValue.GetValues()), Label: "logs.map"}
	default:
		return model.LogValue{Label: "logs.empty_value"}
	}
}

func logString(text string) model.LogValue {
	if strings.IsEmpty(strings.TrimSpace(text)) {
		return model.LogValue{Text: text, Label: "logs.blank_value"}
	}
	return model.LogValue{Text: text}
}

func logList(values []*common.AnyValue) model.LogValue {
	items := make([]model.LogValue, 0, len(values))
	for _, value := range values {
		items = append(items, logValue(value))
	}
	return model.LogValue{Items: items, Label: "logs.list"}
}

func resourceFields(source *logs.ResourceLogs) []model.LogField {
	resource := source.GetResource()
	fields := logFields(resource.GetAttributes())
	for i := range fields {
		fields[i].Label = resourceLabels[fields[i].Name]
	}

	fields = appendContextFields(fields, source.GetSchemaUrl(), resource.GetDroppedAttributesCount())
	if refs := resource.GetEntityRefs(); len(refs) > 0 {
		entities := make([]model.LogValue, 0, len(refs))
		for _, ref := range refs {
			entity := appendContextFields(nil, ref.GetSchemaUrl(), 0)
			entity = append(entity, model.LogField{Label: "logs.entity_type", Value: model.LogValue{Text: ref.GetType()}})
			entity = appendEntityKeys(entity, "logs.entity_id_keys", ref.GetIdKeys())
			entity = appendEntityKeys(entity, "logs.entity_description_keys", ref.GetDescriptionKeys())
			entities = append(entities, model.LogValue{Fields: entity, Label: "logs.map"})
		}
		fields = append(fields, model.LogField{Label: "logs.entity_refs", Value: model.LogValue{Items: entities, Label: "logs.list"}})
	}
	return fields
}

func scopeFields(source *logs.ScopeLogs) []model.LogField {
	scope := source.GetScope()
	var fields []model.LogField
	if name := scope.GetName(); !strings.IsEmpty(name) {
		fields = append(fields, model.LogField{Label: "logs.scope_name", Value: model.LogValue{Text: name}})
	}
	if version := scope.GetVersion(); !strings.IsEmpty(version) {
		fields = append(fields, model.LogField{Label: "logs.scope_version", Value: model.LogValue{Text: version}})
	}
	fields = append(fields, logFields(scope.GetAttributes())...)
	return appendContextFields(fields, source.GetSchemaUrl(), scope.GetDroppedAttributesCount())
}

func appendContextFields(fields []model.LogField, schemaURL string, dropped uint32) []model.LogField {
	if !strings.IsEmpty(schemaURL) {
		fields = append(fields, model.LogField{Label: "logs.schema_url", Value: model.LogValue{Text: schemaURL}})
	}
	if dropped != 0 {
		count := strconv.FormatUint(uint64(dropped), 10)
		fields = append(fields, model.LogField{Label: "logs.dropped_attributes", Value: model.LogValue{Text: count}})
	}
	return fields
}

func appendEntityKeys(fields []model.LogField, label string, keys []string) []model.LogField {
	if len(keys) == 0 {
		return fields
	}
	items := make([]model.LogValue, 0, len(keys))
	for _, key := range keys {
		items = append(items, model.LogValue{Text: key})
	}
	return append(fields, model.LogField{Label: label, Value: model.LogValue{Items: items, Label: "logs.list"}})
}
