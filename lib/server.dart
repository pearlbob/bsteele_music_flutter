// import 'dart:io';
//
// void main() async {
//   HttpServer server = await HttpServer.bind('localhost', 5600);
//   server.transform(WebSocketTransformer()).listen(onWebSocketData);
// }
//
// void onWebSocketData(WebSocket client){
//   client.listen((data) {
//     client.add('Echo: $data');
//   });
// }
