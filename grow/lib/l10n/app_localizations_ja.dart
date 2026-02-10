// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Grow';

  @override
  String get locations => '栽培場所';

  @override
  String get crops => '栽培';

  @override
  String get records => '記録';

  @override
  String get settings => '設定';

  @override
  String get addLocation => '場所を追加';

  @override
  String get editLocation => '場所を編集';

  @override
  String get locationName => '場所の名前';

  @override
  String get locationDescription => '説明（任意）';

  @override
  String get plots => '区画';

  @override
  String get addPlot => '区画を追加';

  @override
  String get editPlot => '区画を編集';

  @override
  String get plotName => '区画名';

  @override
  String get noPlots => '区画がまだありません';

  @override
  String get selectPlot => '区画を選択（任意）';

  @override
  String get nonePlot => '指定なし';

  @override
  String get addCrop => '栽培を追加';

  @override
  String get editCrop => '栽培を編集';

  @override
  String get cultivationName => '栽培名';

  @override
  String get cropName => '作物名';

  @override
  String get variety => '品種';

  @override
  String get memo => 'メモ';

  @override
  String get addRecord => '記録を追加';

  @override
  String get editRecord => '記録を編集';

  @override
  String get date => '日付';

  @override
  String get note => 'メモ';

  @override
  String get activityType => '作業内容';

  @override
  String get activitySowing => '播種';

  @override
  String get activityTransplanting => '定植';

  @override
  String get activityWatering => '水やり';

  @override
  String get activityObservation => '観察';

  @override
  String get activityHarvest => '収穫';

  @override
  String get activityOther => 'その他';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get deleteConfirm => '本当に削除しますか？';

  @override
  String get noLocations => '栽培場所がまだありません';

  @override
  String get noCrops => '栽培がまだありません';

  @override
  String get noRecords => '記録がまだありません';

  @override
  String get selectLocation => '場所を選択';

  @override
  String get allLocations => 'すべての場所';

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get lightMode => 'ライトモード';

  @override
  String get systemMode => 'システム設定に従う';

  @override
  String get takePhoto => '撮影';

  @override
  String get pickFromGallery => 'ギャラリーから選択';

  @override
  String get photos => '写真';

  @override
  String get noPhotos => '写真はまだありません';

  @override
  String get linkTarget => 'リンク先';

  @override
  String get linkToLocation => '栽培場所';

  @override
  String get linkToPlot => '区画';

  @override
  String get linkToCrop => '栽培';

  @override
  String get parentCrop => '元の栽培';

  @override
  String get environmentType => '環境タイプ';

  @override
  String get envOutdoor => '露地';

  @override
  String get envIndoor => '室内';

  @override
  String get envBalcony => 'ベランダ';

  @override
  String get envRooftop => '屋上';

  @override
  String get coverType => '被覆タイプ';

  @override
  String get coverOpen => '露地（覆いなし）';

  @override
  String get coverGreenhouse => 'ハウス';

  @override
  String get coverTunnel => 'トンネル';

  @override
  String get coverColdFrame => 'フレーム';

  @override
  String get soilType => '土壌タイプ';

  @override
  String get soilUnknown => '不明';

  @override
  String get soilCite => '粘土質';

  @override
  String get soilSilt => 'シルト質';

  @override
  String get soilSandy => '砂質';

  @override
  String get soilLoam => '壌土';

  @override
  String get soilPeat => '泥炭';

  @override
  String get soilVolcanic => '火山灰土';

  @override
  String get getLocation => '現在地を取得';

  @override
  String get locationSet => '位置情報を設定しました';

  @override
  String get locationFailed => '位置情報を取得できませんでした';

  @override
  String get autoLinkNearest => '現在地から自動選択';

  @override
  String get analyzing => '写真を分析中…';

  @override
  String get plantDetected => '植物を検出しました';

  @override
  String get landscapeDetected => '風景写真と判定しました';

  @override
  String get noPlantDetected => '植物は検出されませんでした';

  @override
  String get identifyingPlant => '作物を同定中…';

  @override
  String plantIdentified(String name) {
    return '推定: $name';
  }

  @override
  String suggestedLink(String target) {
    return '自動提案: $target';
  }

  @override
  String get apiKeyNotSet => '作物同定APIキーが未設定です';

  @override
  String get plantIdProvider => '植物同定';

  @override
  String get plantIdProviderOff => 'オフ（同定しない）';

  @override
  String get plantIdProviderOffDesc => '小さな畑で不要な場合';

  @override
  String get plantIdProviderPlantId => 'Plant.id（直接API）';

  @override
  String get plantIdProviderPlantIdDesc => '植物特化DB、コスト低め（月200回無料）';

  @override
  String get plantIdProviderServer => 'サーバー経由（高精度）';

  @override
  String get plantIdProviderServerDesc => 'Claude / GPT-4V、雑草も同定可能';

  @override
  String get plantIdApiKey => 'Plant.id APIキー';

  @override
  String get plantIdApiKeyHint => 'APIキーを入力';

  @override
  String get serverUrl => 'サーバーURL';

  @override
  String get serverUrlHint => 'https://grow-server.example.workers.dev';

  @override
  String get serverToken => '認証トークン';

  @override
  String get serverTokenHint => 'Bearer トークンを入力';

  @override
  String get dataSync => 'データ同期';

  @override
  String get syncModeLocal => 'ローカルのみ';

  @override
  String get syncModeLocalDesc => 'データはこの端末のみに保存';

  @override
  String get syncModeCloudflare => 'Cloudflare 同期';

  @override
  String get syncModeCloudflareDesc => 'サーバー経由でデータ・写真を同期';

  @override
  String get syncNow => '今すぐ同期';

  @override
  String get syncing => '同期中…';

  @override
  String syncComplete(int pulled, int pushed, int photos) {
    return '同期完了（取得: $pulled件、送信: $pushed件、写真: $photos枚）';
  }

  @override
  String get syncFailed => '同期に失敗しました';

  @override
  String get plotDetail => '区画詳細';

  @override
  String get cropsInPlot => 'この区画の栽培';

  @override
  String get noCropsInPlot => 'この区画にはまだ栽培がありません';

  @override
  String get growthTimeline => '成長タイムライン';

  @override
  String get createHomepage => 'ホームページを作成';

  @override
  String get createHomepageDesc => 'この栽培の紹介ページを作成します';

  @override
  String get homepageComingSoon => 'ホームページ作成機能は準備中です';

  @override
  String get searchRecords => '記録を検索';

  @override
  String get filterByActivity => '作業で絞り込み';

  @override
  String get allActivities => 'すべての作業';

  @override
  String get searchHint => 'メモ、栽培名、場所名で検索';

  @override
  String get cultivationInfo => '栽培情報';

  @override
  String get seedPacketPhotos => '種袋の写真';

  @override
  String get readFromUrl => 'URLから栽培情報を取得';

  @override
  String get readFromSeedPhoto => '種袋を撮影して読み取る';

  @override
  String get saveSeedPhoto => '種袋の写真を保存（ローカル）';

  @override
  String get cultivationReferences => '参考情報';

  @override
  String get addReference => '参考URLを追加';

  @override
  String get referenceUrl => 'URL';

  @override
  String get referenceTitle => 'タイトル';

  @override
  String get noReferences => '参考情報はまだありません';

  @override
  String get readingUrl => 'URLから情報を読み取り中…';

  @override
  String get readingImage => '種袋を読み取り中…';

  @override
  String get readSuccess => '栽培情報を取得しました';

  @override
  String get readFailed => '情報の取得に失敗しました';

  @override
  String get serverRequired => 'この機能にはサーバー設定が必要です';

  @override
  String get autoFillConfirm => '作物名・品種を自動入力しますか？';

  @override
  String get sowingPeriod => '播種時期';

  @override
  String get harvestPeriod => '収穫時期';

  @override
  String get spacing => '株間';

  @override
  String get seedDepth => '播種深さ';

  @override
  String get sunlight => '日照';

  @override
  String get fertilizerInfo => '施肥';

  @override
  String get cultivationTips => '栽培のコツ';

  @override
  String get sourceUrl => '取得元URL';

  @override
  String get cachedInfo => '（共有データベースから取得）';

  @override
  String get skill => 'スキル';

  @override
  String get farmingMethod => '農法';

  @override
  String get inheritFromSkill => 'スキル設定を使う';
}
