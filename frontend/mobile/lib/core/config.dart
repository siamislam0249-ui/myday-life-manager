/// Set at build time:  --dart-define=API_BASE_URL=https://your-api.example.com/api
/// Default works for the Android emulator talking to a backend on the host PC.
const String apiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000/api');
