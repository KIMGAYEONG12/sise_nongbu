import 'package:flutter/material.dart';

/// 화면 폭 ÷ 높이가 이보다 크면(갤럭시 탭·가로 화면) 앱을 가운데 세로 영역에 보여 준다.
/// 농장·시작 그림은 휴대폰 세로 비율(약 0.46)에 맞춰 그려서, 이보다 넓으면 그림 위아래가 잘리고 글자가 가려진다.
const maxAppAspect = 0.56;

/// MaterialApp.builder: 앱 전체에 공통으로 씌우는 틀.
/// 휴대폰에서는 아무것도 바꾸지 않고, 넓은 화면에서는 휴대폰 비율 영역을 가운데에 두고 양옆을 하늘·풀밭색 바탕으로 채운다.
/// 이렇게 하면 탭을 세로·가로 어느 쪽으로 들어도 시작 화면·농장 화면의 글자와 그림이 잘리지 않는다.
Widget appFrameBuilder(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  final size = mq.size;
  if (size.height <= 0 || size.width / size.height <= maxAppAspect) return child!;
  final w = size.height * maxAppAspect;
  final side = (size.width - w) / 2;
  return ColoredBox(
    color: const Color(0xFF85D0F0),
    child: Stack(children: [
      // 양옆 바탕: 위는 하늘색, 아래는 풀밭색
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF58B6EE), Color(0xFF9AD8F2), Color(0xFFB9E08A), Color(0xFF6FAE48)],
              stops: [0, .45, .7, 1],
            ),
          ),
        ),
      ),
      Positioned(
        left: side,
        top: 0,
        width: w,
        bottom: 0,
        child: DecoratedBox(
          decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24)]),
          child: ClipRect(
            child: MediaQuery(
              // 가운데 영역 안의 화면들은 이 크기를 화면 크기로 알고 그린다 (좌우 시스템 여백은 바깥 바탕이 맡는다)
              data: mq.copyWith(
                size: Size(w, size.height),
                padding: mq.padding.copyWith(left: 0, right: 0),
                viewPadding: mq.viewPadding.copyWith(left: 0, right: 0),
                viewInsets: mq.viewInsets.copyWith(left: 0, right: 0),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    ]),
  );
}
