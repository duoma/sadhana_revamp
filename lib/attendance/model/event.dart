import 'package:json_annotation/json_annotation.dart';
import 'package:sadhana/attendance/model/session.dart';
import 'package:sadhana/constant/wsconstants.dart';
import 'package:sadhana/utils/apputils.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  @JsonKey(name: 'event_pk')
  String eventPk;
  @JsonKey(name: 'event_name')
  String eventName;
  @JsonKey(name: 'name')
  String name;
  @JsonKey(name: 'start_date')
  String startDate;
  @JsonKey(name: 'end_date')
  String endDate;
  @JsonKey(name: 'is_editable')
  bool isEditable;
  @JsonKey(name: 'is_attendance_taken')
  bool isAttendanceTaken;
  @JsonKey(name: 'sessions')
  List<Session> sessions;

  Event();

  DateTime get startDateTime =>
      startDate != null ? WSConstant.wsDateFormat.parse(startDate) : null;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  Event.fromSession(String name, Session session) {
    List<Session> sessions = List();
    sessions.add(session);
    this.name = name;
    this.sessions = sessions;
    this.eventPk = name;
  }

  static Event fromJsonFun(Map<String, dynamic> json) => Event.fromJson(json);
  static List<Event> fromJsonList(dynamic json) {
    // return AppUtils.fromJsonList<Event>(json, Event.fromJsonFun);
    List<Event> events = [];
    if (json is Map && json['data'] != null) {
      events = new List<Event>();
      json['data'].forEach((v) {
        events.add(new Event.fromJson(v));
      });
    }
    return events;
  }

  @override
  String toString() {
    return 'Event{eventPk: $eventPk, eventName: $eventName, name: $name, startDate: $startDate, endDate: $endDate, isEditable: $isEditable, isAttendanceTaken: $isAttendanceTaken, sessions: $sessions}';
  }
}