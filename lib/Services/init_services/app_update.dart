
import 'package:in_app_update/in_app_update.dart';

Future<void> checkForUpdate() async {
    try {
       
      AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
  
        await InAppUpdate.performImmediateUpdate();

         
         await InAppUpdate.startFlexibleUpdate();
         await InAppUpdate.completeFlexibleUpdate();
      } else {
        //  print("No update available.");
      }
    } catch (e) {
      //  print("Failed to check for updates: $e");
    }
  }
