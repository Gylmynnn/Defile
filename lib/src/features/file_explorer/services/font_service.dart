import 'package:defile/src/rust/api/font.dart' as rust;
import 'package:get/get.dart';

class FontService extends GetxService {
  final RxString fontFamily = ''.obs;
  final RxList<String> fonts = <String>[].obs;
  final RxBool isLoading = false.obs;

  Future<void> init() async {
    try {
      fontFamily.value = await rust.getFontFamily();
    } catch (_) {
      fontFamily.value = '';
    }

    await refreshFonts();
  }

  Future<void> refreshFonts() async {
    isLoading.value = true;
    try {
      final list = await rust.listSystemFonts();
      fonts.assignAll(list);
    } catch (_) {
      fonts.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setFont(String name) async {
    fontFamily.value = name;

    try {
      await rust.setFontFamily(name: name);
    } catch (_) {}
  }
}
