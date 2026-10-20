// 빌드한 AAB를 Google Play 내부 테스트 트랙에 올리고 바로 출시한다.
//
// 준비(한 번만): android/play-service-account.json (play-upload 서비스 계정 키, 깃허브에 올리지 않음)
// 실행:
//   cd tools && npm install --no-save googleapis@144   (처음 한 번)
//   node tools/upload_play.mjs "출시 노트 한 줄" "두 번째 줄"
//
// 출시 노트를 안 주면 "버그 수정 및 개선"으로 올린다.
import { readFileSync, createReadStream, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { google } from 'googleapis';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const packageName = 'com.sise_nongbu';
const keyFile = join(root, 'android', 'play-service-account.json');
const aab = join(root, 'build', 'app', 'outputs', 'bundle', 'release', 'app-release.aab');
// 기본은 내부 테스트. 비공개 테스트(Alpha)에 올리려면 PLAY_TRACK=alpha
const track = process.env.PLAY_TRACK || 'internal';

if (!existsSync(keyFile)) throw new Error(`서비스 계정 키가 없어요: ${keyFile}`);
if (!existsSync(aab)) throw new Error(`AAB가 없어요. 먼저 flutter build appbundle 을 실행하세요: ${aab}`);

const notes = process.argv.slice(2).join('\n') || '버그 수정 및 개선';
const version = /^version:\s*(\S+)/m.exec(readFileSync(join(root, 'pubspec.yaml'), 'utf8'))?.[1] ?? '';

const auth = new google.auth.GoogleAuth({ keyFile, scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
const play = google.androidpublisher({ version: 'v3', auth });

const { data: edit } = await play.edits.insert({ packageName });
console.log('수정 시작:', edit.id);

console.log('AAB 올리는 중… (몇 분 걸릴 수 있어요)');
const { data: bundle } = await play.edits.bundles.upload(
  { packageName, editId: edit.id, media: { mimeType: 'application/octet-stream', body: createReadStream(aab) } },
  { timeout: 15 * 60 * 1000 },
);
console.log('올린 버전 코드:', bundle.versionCode);

await play.edits.tracks.update({
  packageName,
  editId: edit.id,
  track,
  requestBody: {
    track,
    releases: [{
      name: `${bundle.versionCode} (${version.split('+')[0]})`,
      versionCodes: [String(bundle.versionCode)],
      status: 'completed',
      releaseNotes: [{ language: 'ko-KR', text: notes }],
    }],
  },
});

const { data: done } = await play.edits.commit({ packageName, editId: edit.id });
console.log(`출시 완료 (${track} 트랙): 버전 ${bundle.versionCode} (edit ${done.id})`);
