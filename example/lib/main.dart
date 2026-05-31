import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:getxtra_storage/getxtra_storage.dart';

void main() async {
  await GetStorage.init();
  runApp(App());
}

class Controller extends GetxController {
  final box = GetStorage();

  RxBool isDark = false.obs;

  @override
  void onInit() {
    super.onInit();
    isDark.value = box.read('darkmode') ?? false;
  }

  ThemeData get theme => isDark.value ? ThemeData.dark() : ThemeData.light();

  void changeTheme(bool val) {
    isDark.value = val;
    box.write('darkmode', val);
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(Controller());
    return Obx(() => GetMaterialApp(
          theme: controller.theme,
          home: Scaffold(
            appBar: AppBar(title: Text("Get Storage")),
            body: Center(
              child: SwitchListTile(
                value: controller.isDark.value,
                title: Text("Touch to change ThemeMode"),
                onChanged: controller.changeTheme,
              ),
            ),
          ),
        ));
  }
}
