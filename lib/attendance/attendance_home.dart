import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:sadhana/attendance/attendance_constant.dart';
import 'package:sadhana/attendance/attendance_summary.dart';
import 'package:sadhana/attendance/model/dvd_info.dart';
import 'package:sadhana/attendance/model/session.dart';
import 'package:sadhana/attendance/model/user_role.dart';
import 'package:sadhana/attendance/submit_attendance.dart';
import 'package:sadhana/attendance/widgets/date_picker_with_event.dart';
import 'package:sadhana/attendance/widgets/dvd_form.dart';
import 'package:sadhana/auth/registration/Inputs/text-input.dart';
import 'package:sadhana/common.dart';
import 'package:sadhana/constant/constant.dart';
import 'package:sadhana/constant/wsconstants.dart';
import 'package:sadhana/model/cachedata.dart';
import 'package:sadhana/service/apiservice.dart';
import 'package:sadhana/utils/app_response_parser.dart';
import 'package:sadhana/utils/apputils.dart';
import 'package:sadhana/widgets/base_state.dart';
import 'package:sadhana/widgets/remark_picker.dart';
import 'package:sadhana/widgets/title_with_subtitle.dart';
import 'package:sadhana/wsmodel/appresponse.dart';

class AttendanceHomePage extends StatefulWidget {
  static const String routeName = '/attendance_home';
  final DateTime date;

  AttendanceHomePage({this.date});

  @override
  AttendanceHomePageState createState() => AttendanceHomePageState();
}

enum PopUpMenu {
  changeDate,
  attendanceSummary,
  submitAttendance,
}

class AttendanceHomePageState extends BaseState<AttendanceHomePage> {
  bool _selectAll = false;
  ApiService _api = ApiService();
  Session session;
  Hero _dvdFormButton;
  Hero _saveButton;
  UserRole _userRole;
  List<DateTime> _sessionDates = List();
  DateTime selectedDate = CacheData.today;
  bool isSimcityGroup = false;
  final GlobalKey<FormState> _attendanceForm = GlobalKey<FormState>();
  bool isReadOnly = false;
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.date != null) selectedDate = widget.date;
    loadData();
  }

  loadData() async {
    startOverlay();
    try {
      _userRole = CacheData.userRole;
      if (_userRole != null && _userRole.isAttendanceCord) {
        isSimcityGroup = _userRole.isSimCityGroup;
        await loadSessionDates();
        await loadSession(selectedDate);
        setState(() {
          setReadOnlyField();
        });
      } else {
        CommonFunction.alertDialog(
            context: context, msg: "You don't have right for Attendance");
      }
    } catch (e, s) {
      print(e);
      print(s);
      CommonFunction.displayErrorDialog(context: context);
    }
    stopOverlay();
  }

  loadSession(DateTime date) async {
    startOverlay();
    try {
      String strDate = WSConstant.wsDateFormat.format(date);
      if (_sessionDates.contains(date)) {
        Response res =
            await _api.getAttendanceSession(strDate, _userRole.groupName);
        AppResponse appResponse =
            AppResponseParser.parseResponse(res, context: context);
        if (appResponse.status == WSConstant.SUCCESS_CODE) {
          setState(() {
            session = Session.fromJson(appResponse.data);
            isEditMode = true;
          });
          print(session);
        }
      } else {
        Response res = await _api.getMBAOfGroup(strDate, _userRole.groupName);
        AppResponse appResponse =
            AppResponseParser.parseResponse(res, context: context);
        if (appResponse.status == WSConstant.SUCCESS_CODE) {
          List<Attendance> attendances =
              Attendance.fromJsonList(appResponse.data);
          String sessionType = isSimcityGroup
              ? WSConstant.sessionType_GD
              : WSConstant.sessionType_General;
          setState(() {
            session = Session.fromAttendanceList(
                _userRole.groupName, strDate, sessionType, attendances);
            print('blank session' + session.toString());
          });
        }
      }
    } catch (e, s) {
      print(s);
    }
    stopOverlay();
  }

  loadSessionDates() async {
    Response res = await _api.getSessionDates(_userRole.groupName);
    AppResponse appResponse =
        AppResponseParser.parseResponse(res, context: context);
    if (appResponse.status == WSConstant.SUCCESS_CODE) {
      List<String> strDates =
          (appResponse.data as List)?.map((e) => e.toString())?.toList();
      if (strDates != null)
        strDates.forEach((str) => _sessionDates.add(AppUtils.tryParse(
            str, [WSConstant.DATE_FORMAT],
            throwErrorIfNotParse: true)));
    }
  }

  onCheck(Attendance attendance) {
    setState(() {
      attendance.isPresent = !attendance.isPresent;
      if (attendance.isPresent) attendance.reason = '';
    });
  }

  @override
  Widget pageToDisplay() {
    return Scaffold(
      // backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        title: InkWell(
          onTap: () => _onSelectDate(),
          child: Row(
            children: <Widget>[
              AppTitleWithSubTitle(
                title: new DateFormat('dd MMM yyyy').format(selectedDate),
                subTitle: _userRole.groupTitle,
              ),
              SizedBox(
                width: 10,
              ),
              Icon(Icons.date_range),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(55),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white30,
              border: Border(
                top: BorderSide(
                  width: 0.0,
                ),
              ),
            ),
            child: ListTile(
              title: Text(
                'Select ALL',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              trailing: Checkbox(
                activeColor: Colors.amber,
                checkColor: Colors.black,
                value: _selectAll,
                onChanged: isReadOnly ? null : _onSelectAll,
              ),
              onTap: isReadOnly
                  ? null
                  : () {
                      _onSelectAll(!_selectAll);
                    },
              selected: true,
            ),
          ),
        ),
        actions: _buildAction(),
      ),
      body: SafeArea(
        child: Form(
          key: _attendanceForm,
          child: session != null ? _buildNewListView() : Container(),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          session != null ? _buildFloatingActionButton() : Container(),
    );
  }

  Widget userTile({
    @required Attendance attendance,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(5),
        ),
      ),
      child: Column(
        children: <Widget>[
          ListTile(
            title: Text(attendance.name),
            trailing: Checkbox(
              activeColor: Colors.red.shade500,
              onChanged: isReadOnly
                  ? null
                  : (val) {
                      onCheck(attendance);
                    },
              value: attendance.isPresent,
            ),
            onTap: isReadOnly
                ? null
                : () {
                    onCheck(attendance);
                  },
          ),
          !attendance.isPresent && isSimcityGroup
              ? Container(
                  padding: EdgeInsets.fromLTRB(15, 0, 15, 10),
                  child: TextInputField(
                    valueText: attendance.reason,
                    maxLength: 125,
                    showCounter: false,
                    enabled: !isReadOnly,
                    isRequiredValidation: true,
                    labelText: "Reason for Absent",
                    onSaved: (val) => attendance.reason = val,
                    padding: EdgeInsets.all(0),
                    contentPadding: EdgeInsets.all(13),
                  ),
                )
              : Container()
        ],
      ),
    );
  }

  Widget _buildNewListView() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 12),
      itemCount: session.attendance.length,
      itemBuilder: (context, index) {
        if (session.attendance.length - 1 == index) {
          return Container(
            margin: EdgeInsets.only(bottom: 80),
            child: userTile(attendance: session.attendance[index]),
          );
        }
        return userTile(attendance: session.attendance[index]);
      },
      separatorBuilder: (context, index) {
        return Divider();
      },
    );
  }

  List<Widget> _buildAction() {
    return <Widget>[
      (!isReadOnly & isEditMode)
          ? IconButton(icon: Icon(Icons.delete), onPressed: _onDeleteClick)
          : Container(),
      PopupMenuButton<PopUpMenu>(
        onSelected: _onPopupSelected,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<PopUpMenu>>[
          //const PopupMenuItem<PopUpMenu>(value: PopUpMenu.changeDate, child: Text('Change Date')),
          !isSimcityGroup
              ? const PopupMenuItem<PopUpMenu>(
                  value: PopUpMenu.submitAttendance,
                  child: Text('Submit Attendance'))
              : null,
          const PopupMenuItem<PopUpMenu>(
              value: PopUpMenu.attendanceSummary,
              child: Text('Attendance Summary')),
        ],
        //icon: Icon(Icons.menu),
      ),
    ];
  }

  Widget _buildFloatingActionButton() {
    return Container(
      height: 60,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FloatingActionButton(
            heroTag: _dvdFormButton,
            onPressed: () => _onDVDClick(),
            backgroundColor: Colors.white,
            child: isSimcityGroup
                ? Icon(Icons.chat,
                    color: AppUtils.isNullOrEmpty(session.remark)
                        ? Colors.red
                        : Colors.blueAccent)
                : Image.asset('assets/icon/iconfinder_BT_dvd_905549.png',
                    color: Color(0xFFce0e11)),
          ),
          SizedBox(width: 20),
          !isReadOnly
              ? FloatingActionButton.extended(
                  heroTag: _saveButton,
                  onPressed: _onSubmit,
                  //backgroundColor: Colors.white,
                  icon: Icon(Icons.check, color: Colors.white),
                  label: Text('Save', style: TextStyle(color: Colors.white)),
                )
              : Container(),
        ],
      ),
    );
  }

  Future<void> _onSelectDate() async {
    final DateTime picked =
        await showDatePickerWithEvents(context, selectedDate, _sessionDates);
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      if (isSimcityGroup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceHomePage(date: selectedDate),
          ),
        );
      } else {
        setReadOnlyField();
        loadSession(selectedDate);
      }
    }
  }

  void setReadOnlyField() {
    setState(() {
      isReadOnly = isSelectedDateReadOnly();
    });
  }

  bool isSelectedDateReadOnly() {
    return CommonFunction.tryCatchSync(context, () {
      if (_userRole.isSimCityGroup) {
        if (selectedDate.isBefore(CacheData.today
            .add(Duration(days: -AttendanceConstant.SIMCITY_MAX_ALLOWED))))
          return true;
        else
          return false;
      } else {
        if (selectedDate.month == CacheData.today.month) {
          if (isCurrentMonthAttendanceSubmitted())
            return true;
          else
            return false;
        }
        if (CacheData.pendingMonth != null &&
            selectedDate.month >= CacheData.pendingMonth.month)
          return false;
        else {
          if (CacheData.pendingMonth == null) {
            DateTime lastSubmittedMonth = getLastSubmittedMonth();
            if (lastSubmittedMonth == null ||
                selectedDate.month > lastSubmittedMonth.month) return false;
          }
        }
        return true;
      }
    });
  }

  DateTime getLastSubmittedMonth() {
    if (_sessionDates != null && _sessionDates.isNotEmpty) {
      _sessionDates.sort((a, b) => b.compareTo(a));
      return _sessionDates.first;
    }
    return null;
  }

  bool isCurrentMonthAttendanceSubmitted() {
    return CacheData.pendingMonth == null && isContainCurrentMonthDates();
  }

  bool isContainCurrentMonthDates() {
    for (DateTime sessionDate in _sessionDates) {
      if (sessionDate.month == CacheData.today.month) return true;
    }
    return false;
  }

  void _onPopupSelected(PopUpMenu result) {
    switch (result) {
      case PopUpMenu.changeDate:
        _onSelectDate();
        break;
      case PopUpMenu.attendanceSummary:
        Navigator.pushNamed(context, AttendanceSummaryPage.routeName);
        break;
      case PopUpMenu.submitAttendance:
        onSubmitAttendanceClick();
        break;
      default:
    }
  }

  void onSubmitAttendanceClick() async {
    startOverlay();
    try {
      await CacheData.loadPendingMonthForAttendance(
          _userRole.groupName, context);
      if (CacheData.pendingMonth == null) {
        CommonFunction.alertDialog(
            context: context, msg: "You have already submmited Attendance");
      } else {
        goToAttendanceSubmitPage();
      }
    } catch (e, s) {
      print(s);
      CommonFunction.displayErrorDialog(context: context);
    }
    stopOverlay();
  }

  void onAttendanceSubmitted(bool isSubmitted) {
    setState(() {
      setReadOnlyField();
    });
  }

  void _onSelectAll(bool value) {
    _selectAll = value;
    setState(() {
      session.attendance.forEach((res) {
        res.isPresent = _selectAll;
      });
    });
  }

  Future<void> _onDVDClick() async {
    /*Navigator.of(context).push(new MaterialPageRoute<Null>(
          builder: (BuildContext context) {
            return new DVDForm(session: session);
          },
          fullscreenDialog: true));*/
    if (isSimcityGroup) {
      showDialog<String>(
          context: context,
          builder: (_) {
            return RemarkPickerDialog(
              title: Text("Remark"),
              remark: session.remark,
              isEnabled: !isReadOnly,
            );
          }).then(onRemarkEntered);
    } else {
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Center(
                child: Text('MBA DVD Details'),
              ),
              children: <Widget>[
                Builder(
                  builder: (BuildContext context) => DVDForm(
                    session: session,
                    onDVDSubmit: _onDVDEntered,
                    isReadOnly: isReadOnly,
                  ),
                )
              ],
            );
          });
    }
  }

  onRemarkEntered(String remark) {
    if (!AppUtils.isNullOrEmpty(remark)) {
      setState(() {
        session.remark = remark;
      });
    }
  }

  void _onDVDEntered(DVDInfo dvdInfo) {
    DVDInfo.setSession(session, dvdInfo);
  }

  _onDeleteClick() {
    CommonFunction.alertDialog(
        context: context,
        title: 'Are you sure ?',
        msg:
            "Do you want to delete ${Constant.APP_DATE_FORMAT.format(selectedDate)} Session?",
        showCancelButton: true,
        doneButtonFn: deleteSession);
  }

  deleteSession() async {
    Navigator.pop(context);
    CommonFunction.tryCatchAsync(context, () async {
      Response res = await _api.deleteAttendanceSession(
          session.dateTime, _userRole.groupName);
      AppResponse appResponse =
          AppResponseParser.parseResponse(res, context: context);
      if (appResponse.status == WSConstant.SUCCESS_CODE) {
        setState(() {
          _sessionDates.remove(session.dateTime);
          selectedDate = session.dateTime;
        });
        CommonFunction.alertDialog(
            closeable: false,
            context: context,
            msg: "Attendance deleted successfully.",
            doneButtonFn: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceHomePage(date: selectedDate),
                ),
              );
            });
      }
    });
  }

  void _onSubmit() async {
    if (CacheData.isAttendanceSubmissionPending() &&
        CacheData.pendingMonth.month != selectedDate.month) {
      String strMonth = DateFormat.yMMM().format(CacheData.pendingMonth);
      CommonFunction.alertDialog(
          context: context,
          msg:
              "$strMonth month's attendance submission is pending, Please submit Attendance to continue.",
          doneButtonFn: () {
            Navigator.pop(context);
            goToAttendanceSubmitPage();
          });
      return;
    }
    startOverlay();
    try {
      if (_attendanceForm.currentState.validate()) {
        _attendanceForm.currentState.save();
        if (_validateDVD() && _validateAttendance()) {
          print(session);
          Response res = await _api.submitAttendanceSession(session);
          AppResponse appResponse =
              AppResponseParser.parseResponse(res, context: context);
          if (appResponse.status == WSConstant.SUCCESS_CODE) {
            setState(() {
              _sessionDates.add(session.dateTime);
              isEditMode = true;
            });
            if (CacheData.pendingMonth == null)
              CacheData.pendingMonth = session.dateTime;
            CommonFunction.alertDialog(
                closeable: false,
                context: context,
                msg: "Attendance submitted successfully.",
                doneButtonFn: () {
                  Navigator.pop(context);
                  //Navigator.pop(context);
                });
          }
        }
      }
    } catch (e, s) {
      print(s);
      CommonFunction.displayErrorDialog(context: context, error: e);
    }
    stopOverlay();
  }

  void goToAttendanceSubmitPage() {
    if (CacheData.pendingMonth != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubmitAttendancePage(
            CacheData.pendingMonth,
            onAttendanceSubmit: onAttendanceSubmitted,
          ),
        ),
      );
    }
  }

  bool _validateDVD() {
    if (!isSimcityGroup) {
      if (session.dvdNo == null &&
          session.dvdPart == null &&
          session.remark == null) {
        CommonFunction.alertDialog(
            context: context, msg: "Please fill DVD Details", type: 'error');
        return false;
      }
    }
    return true;
  }

  bool _validateAttendance() {
    bool isAnyPresent = false;
    for (Attendance attendance in session.attendance) {
      if (attendance.isPresent) {
        isAnyPresent = true;
        break;
      }
    }
    if (!isAnyPresent) {
      CommonFunction.alertDialog(
          context: context, msg: "One Person should be present", type: 'error');
      return false;
    }
    return true;
  }
}
