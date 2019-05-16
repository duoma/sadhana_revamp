import 'package:flutter/material.dart';
import 'package:sadhana/model/cachedata.dart';
import 'package:sadhana/model/sadhana.dart';

class AppUtils {


  static bool equalsIgnoreCase(String string1, String string2) {
    return string1?.toLowerCase() == string2?.toLowerCase();
  }

  static bool isLightBrightness(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light;
  }

  static bool isSadhanaExist(String name) {
    for(Sadhana sadhana in CacheData.getSadhanas()) {
      if(equalsIgnoreCase(sadhana.name, name))
        return true;
    }
    return false;
  }
}