// Show some data about the app and it's environment.
// class CommunityJams extends StatefulWidget {
//   const CommunityJams({super.key});
//
//   @override
//   CommunityJamsState createState() => CommunityJamsState();
//
//   static const String routeName = 'communityJams';
// }
//
// class CommunityJamsState extends State<CommunityJams> with WidgetsBindingObserver {
//   @override
//   initState() {
//     super.initState();
//
//     app.clearMessage();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);
//     app.screenInfo.refresh(context);
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).colorScheme.surface,
//       appBar: appWidgetHelper.backBar(title: 'Community Jams'),
//       body: DefaultTextStyle(
//         style: generateAppTextStyle(color: Colors.black87, fontSize: app.screenInfo.fontSize),
//         child: Column(
//           // padding: const EdgeInsets.all(8.0),
//           children: [
//             Expanded(
//               child: ListView(//controller: scrollController,
//                   children: <Widget>[
//                 app.messageTextWidget(),
//                 const AppVerticalSpace(
//                   space: 200,
//                 ),
//                 const Text(
//                   'The bsteeleMusicApp has been motivated by Community Jams.',
//                 ),
//                 Image(
//                   image: const AssetImage('lib/assets/cj_qr_code.png'),
//                   width: max(200, app.screenInfo.mediaWidth / 5),
//                   height: max(200, app.screenInfo.mediaWidth / 5),
//                   semanticLabel: "communityjams.org website",
//                   alignment: Alignment.topLeft,
//                 ),
//                 AppWrapFullWidth(
//                   children: <Widget>[
//                     const Text(
//                       'See ',
//                     ),
//                     InkWell(
//                       onTap: () {
//                         openLink('http://communityjams.org/');
//                       },
//                       child: Text(
//                         'CommunityJams.org',
//                         style: generateAppLinkTextStyle(fontSize: app.screenInfo.fontSize),
//                       ),
//                     ),
//                     const Text(
//                       '.',
//                     ),
//                   ],
//                 ),
//                 const AppSpace(),
//                 AppWrapFullWidth(
//                   spacing: 20,
//                   children: <Widget>[
//                     const Text('The Community Jams park QR is below:'),
//                     Icon(
//                       Icons.arrow_downward,
//                       size: 1.5 * app.screenInfo.fontSize,
//                     ),
//                   ],
//                 ),
//                 const AppVerticalSpace(
//                   space: 300,
//                 ),
//                 const AppWrapFullWidth(
//                   children: <Widget>[
//                     Text(
//                       'When in the park with Community Jams,\n'
//                       'share this link to the bsteeleMusicApp with others in the park:',
//                     ),
//                   ],
//                 ),
//                 const AppVerticalSpace(
//                   space: 25,
//                 ),
//                 Image(
//                   image: const AssetImage('lib/assets/cj_park_qr_code.png'),
//                   width: max(200, app.screenInfo.mediaWidth / 5),
//                   height: max(200, app.screenInfo.mediaWidth / 5),
//                   semanticLabel: "Community Jams website in the park",
//                   alignment: Alignment.topLeft,
//                 ),
//                 const AppVerticalSpace(
//                   space: 400,
//                 ),
//               ]),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
