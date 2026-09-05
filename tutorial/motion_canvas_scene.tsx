/**
 * Motion Canvas Scene: QR Code Generator Tutorial (Vertical 9:16)
 * Resolution: 1080 x 1920
 * Frame Rate: 60 FPS
 * Duration: ~55s
 */

import {makeScene2D, Circle, Txt, Rect, Layout, all, createRef, sequence, easeInOutCubic, easeOutBack, loop} from '@motion-canvas/2d';

export default makeScene2D(function* (view) {
  // Background
  const bg = createRef<Rect>();
  const title = createRef<Txt>();
  const subtitle = createRef<Txt>();
  const badgeCard = createRef<Rect>();
  const installerCard = createRef<Rect>();
  const portableCard = createRef<Rect>();
  const qrBox = createRef<Rect>();
  const trayMenu = createRef<Rect>();
  const ctaCard = createRef<Rect>();

  view.add(
    <Rect
      ref={bg}
      width={1080}
      height={1920}
      fill={'#0f172a'}
    />
  );

  // -------------------------------------------------------------
  // SCENE 1: Hook & Introduction (00:00 - 00:06)
  // -------------------------------------------------------------
  view.add(
    <Layout layout direction={'column'} alignItems={'center'} gap={30} y={-200}>
      <Txt
        ref={title}
        text={'🔳 QR CODE GENERATOR'}
        fontFamily={'Inter, sans-serif'}
        fontWeight={800}
        fontSize={56}
        fill={'#38bdf8'}
        opacity={0}
        scale={0.8}
      />
      <Txt
        ref={subtitle}
        text={'Free • Offline • Windows 10/11'}
        fontFamily={'Inter, sans-serif'}
        fontWeight={600}
        fontSize={36}
        fill={'#94a3b8'}
        opacity={0}
      />
    </Layout>
  );

  yield* all(
    title().opacity(1, 0.8, easeOutBack),
    title().scale(1, 0.8, easeOutBack),
    subtitle().opacity(1, 0.8),
  );

  // -------------------------------------------------------------
  // SCENE 2: Hard Requirements (00:06 - 00:13)
  // -------------------------------------------------------------
  view.add(
    <Rect
      ref={badgeCard}
      width={880}
      height={220}
      radius={24}
      fill={'#1e293b'}
      stroke={'#22c55e'}
      lineWidth={4}
      y={100}
      opacity={0}
      scale={0.8}
    >
      <Txt
        text={'⚡ ZERO PYTHON REQUIRED!\n💻 Windows 10 & 11 (64-bit)'}
        fontFamily={'Inter, sans-serif'}
        fontWeight={700}
        fontSize={40}
        fill={'#f8fafc'}
        textAlign={'center'}
      />
    </Rect>
  );

  yield* all(
    badgeCard().opacity(1, 0.6, easeOutBack),
    badgeCard().scale(1, 0.6, easeOutBack),
  );
  yield* badgeCard().y(80, 0.4, easeInOutCubic);

  // -------------------------------------------------------------
  // SCENE 3: Two Installation Options (00:13 - 00:24)
  // -------------------------------------------------------------
  yield* all(
    badgeCard().opacity(0, 0.4),
    title().text('📦 CHOOSE YOUR VERSION', 0.4),
  );

  view.add(
    <Layout layout direction={'column'} gap={40} y={150}>
      <Rect
        ref={installerCard}
        width={880}
        height={260}
        radius={24}
        fill={'#1e293b'}
        stroke={'#38bdf8'}
        lineWidth={3}
        opacity={0}
        x={-600}
      >
        <Txt
          text={'1️⃣ Windows Setup Installer (.exe)\n• Start Menu & Desktop Icon\n• Clean Uninstaller in Settings'}
          fontFamily={'Inter, sans-serif'}
          fontWeight={600}
          fontSize={34}
          fill={'#f1f5f9'}
          textAlign={'left'}
          x={-20}
        />
      </Rect>

      <Rect
        ref={portableCard}
        width={880}
        height={260}
        radius={24}
        fill={'#1e293b'}
        stroke={'#a855f7'}
        lineWidth={3}
        opacity={0}
        x={600}
      >
        <Txt
          text={'2️⃣ Portable Standalone (.exe)\n• Zero Installation Needed\n• Double-click or run from USB'}
          fontFamily={'Inter, sans-serif'}
          fontWeight={600}
          fontSize={34}
          fill={'#f1f5f9'}
          textAlign={'left'}
          x={-20}
        />
      </Rect>
    </Layout>
  );

  yield* sequence(
    0.2,
    all(installerCard().opacity(1, 0.6), installerCard().x(0, 0.6, easeOutBack)),
    all(portableCard().opacity(1, 0.6), portableCard().x(0, 0.6, easeOutBack)),
  );

  // -------------------------------------------------------------
  // SCENE 4: Customization & Outputs (00:24 - 00:42)
  // -------------------------------------------------------------
  yield* all(
    installerCard().opacity(0, 0.4),
    portableCard().opacity(0, 0.4),
    title().text('🎨 INSTANT GENERATION', 0.4),
  );

  view.add(
    <Rect
      ref={qrBox}
      width={460}
      height={460}
      radius={28}
      fill={'#ffffff'}
      y={0}
      scale={0}
    >
      <Txt
        text={'🔳 [ QR PREVIEW ]\nPNG • JPEG • SVG'}
        fontFamily={'Inter, sans-serif'}
        fontWeight={800}
        fontSize={36}
        fill={'#0f172a'}
        textAlign={'center'}
      />
    </Rect>
  );

  yield* qrBox().scale(1, 0.6, easeOutBack);

  // -------------------------------------------------------------
  // SCENE 5: Tray & Outro (00:42 - 00:55)
  // -------------------------------------------------------------
  yield* all(
    qrBox().scale(0, 0.4),
    title().text('🚀 DOWNLOAD FREE NOW', 0.4),
  );

  view.add(
    <Rect
      ref={ctaCard}
      width={880}
      height={420}
      radius={28}
      fill={'#1e293b'}
      stroke={'#f59e0b'}
      lineWidth={4}
      y={120}
      opacity={0}
      scale={0.8}
    >
      <Txt
        text={'⬇️ Links in Description / Bio!\n\n▶️ YouTube: @LocalAiLabKh\n🌐 Facebook: LocalAiLab'}
        fontFamily={'Inter, sans-serif'}
        fontWeight={700}
        fontSize={38}
        fill={'#f8fafc'}
        textAlign={'center'}
      />
    </Rect>
  );

  yield* all(
    ctaCard().opacity(1, 0.6, easeOutBack),
    ctaCard().scale(1, 0.6, easeOutBack),
  );
});
