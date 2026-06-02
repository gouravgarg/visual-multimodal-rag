import 'app_config.dart';

const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "CognitoUserPool": {
          "Default": {
            "PoolId": "${AppConfig.cognitoUserPoolId}",
            "AppClientId": "${AppConfig.cognitoAppClientId}",
            "Region": "${AppConfig.cognitoRegion}"
          }
        }
      }
    }
  }
}''';
