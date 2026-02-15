import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'Grow'**
  String get appTitle;

  /// No description provided for @locations.
  ///
  /// In ja, this message translates to:
  /// **'栽培場所'**
  String get locations;

  /// No description provided for @crops.
  ///
  /// In ja, this message translates to:
  /// **'栽培'**
  String get crops;

  /// No description provided for @records.
  ///
  /// In ja, this message translates to:
  /// **'観察'**
  String get records;

  /// No description provided for @settings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settings;

  /// No description provided for @addLocation.
  ///
  /// In ja, this message translates to:
  /// **'場所を追加'**
  String get addLocation;

  /// No description provided for @editLocation.
  ///
  /// In ja, this message translates to:
  /// **'場所を編集'**
  String get editLocation;

  /// No description provided for @locationName.
  ///
  /// In ja, this message translates to:
  /// **'場所の名前'**
  String get locationName;

  /// No description provided for @locationDescription.
  ///
  /// In ja, this message translates to:
  /// **'説明（任意）'**
  String get locationDescription;

  /// No description provided for @plots.
  ///
  /// In ja, this message translates to:
  /// **'区画'**
  String get plots;

  /// No description provided for @addPlot.
  ///
  /// In ja, this message translates to:
  /// **'区画を追加'**
  String get addPlot;

  /// No description provided for @editPlot.
  ///
  /// In ja, this message translates to:
  /// **'区画を編集'**
  String get editPlot;

  /// No description provided for @plotName.
  ///
  /// In ja, this message translates to:
  /// **'区画名'**
  String get plotName;

  /// No description provided for @noPlots.
  ///
  /// In ja, this message translates to:
  /// **'区画がまだありません'**
  String get noPlots;

  /// No description provided for @selectPlot.
  ///
  /// In ja, this message translates to:
  /// **'区画を選択（任意）'**
  String get selectPlot;

  /// No description provided for @nonePlot.
  ///
  /// In ja, this message translates to:
  /// **'指定なし'**
  String get nonePlot;

  /// No description provided for @addCrop.
  ///
  /// In ja, this message translates to:
  /// **'栽培を追加'**
  String get addCrop;

  /// No description provided for @editCrop.
  ///
  /// In ja, this message translates to:
  /// **'栽培を編集'**
  String get editCrop;

  /// No description provided for @cultivationName.
  ///
  /// In ja, this message translates to:
  /// **'栽培名'**
  String get cultivationName;

  /// No description provided for @cropName.
  ///
  /// In ja, this message translates to:
  /// **'作物名'**
  String get cropName;

  /// No description provided for @variety.
  ///
  /// In ja, this message translates to:
  /// **'品種'**
  String get variety;

  /// No description provided for @memo.
  ///
  /// In ja, this message translates to:
  /// **'メモ'**
  String get memo;

  /// No description provided for @addRecord.
  ///
  /// In ja, this message translates to:
  /// **'記録を追加'**
  String get addRecord;

  /// No description provided for @editRecord.
  ///
  /// In ja, this message translates to:
  /// **'記録を編集'**
  String get editRecord;

  /// No description provided for @date.
  ///
  /// In ja, this message translates to:
  /// **'日付'**
  String get date;

  /// No description provided for @note.
  ///
  /// In ja, this message translates to:
  /// **'メモ'**
  String get note;

  /// No description provided for @activityType.
  ///
  /// In ja, this message translates to:
  /// **'作業内容'**
  String get activityType;

  /// No description provided for @activitySowing.
  ///
  /// In ja, this message translates to:
  /// **'播種'**
  String get activitySowing;

  /// No description provided for @activityTransplanting.
  ///
  /// In ja, this message translates to:
  /// **'定植'**
  String get activityTransplanting;

  /// No description provided for @activityWatering.
  ///
  /// In ja, this message translates to:
  /// **'水やり'**
  String get activityWatering;

  /// No description provided for @activityObservation.
  ///
  /// In ja, this message translates to:
  /// **'観察'**
  String get activityObservation;

  /// No description provided for @activityHarvest.
  ///
  /// In ja, this message translates to:
  /// **'収穫'**
  String get activityHarvest;

  /// No description provided for @activityOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get activityOther;

  /// No description provided for @activityPruning.
  ///
  /// In ja, this message translates to:
  /// **'剪定'**
  String get activityPruning;

  /// No description provided for @activityWeeding.
  ///
  /// In ja, this message translates to:
  /// **'除草'**
  String get activityWeeding;

  /// No description provided for @activityBedMaking.
  ///
  /// In ja, this message translates to:
  /// **'畝作り'**
  String get activityBedMaking;

  /// No description provided for @activityTilling.
  ///
  /// In ja, this message translates to:
  /// **'耕運'**
  String get activityTilling;

  /// No description provided for @activityPotUp.
  ///
  /// In ja, this message translates to:
  /// **'鉢上'**
  String get activityPotUp;

  /// No description provided for @activityCutting.
  ///
  /// In ja, this message translates to:
  /// **'挿木'**
  String get activityCutting;

  /// No description provided for @activityFlowering.
  ///
  /// In ja, this message translates to:
  /// **'花付'**
  String get activityFlowering;

  /// No description provided for @activityShipping.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get activityShipping;

  /// No description provided for @activityManagement.
  ///
  /// In ja, this message translates to:
  /// **'管理'**
  String get activityManagement;

  /// No description provided for @workHours.
  ///
  /// In ja, this message translates to:
  /// **'作業時間'**
  String get workHours;

  /// No description provided for @materials.
  ///
  /// In ja, this message translates to:
  /// **'資材'**
  String get materials;

  /// No description provided for @save.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get delete;

  /// No description provided for @deleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'本当に削除しますか？'**
  String get deleteConfirm;

  /// No description provided for @noLocations.
  ///
  /// In ja, this message translates to:
  /// **'栽培場所がまだありません'**
  String get noLocations;

  /// No description provided for @noCrops.
  ///
  /// In ja, this message translates to:
  /// **'栽培がまだありません'**
  String get noCrops;

  /// No description provided for @noRecords.
  ///
  /// In ja, this message translates to:
  /// **'記録がまだありません'**
  String get noRecords;

  /// No description provided for @selectLocation.
  ///
  /// In ja, this message translates to:
  /// **'場所を選択'**
  String get selectLocation;

  /// No description provided for @allLocations.
  ///
  /// In ja, this message translates to:
  /// **'すべての場所'**
  String get allLocations;

  /// No description provided for @language.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In ja, this message translates to:
  /// **'テーマ'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In ja, this message translates to:
  /// **'ダークモード'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In ja, this message translates to:
  /// **'ライトモード'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In ja, this message translates to:
  /// **'システム設定に従う'**
  String get systemMode;

  /// No description provided for @takePhoto.
  ///
  /// In ja, this message translates to:
  /// **'撮影'**
  String get takePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In ja, this message translates to:
  /// **'ギャラリーから選択'**
  String get pickFromGallery;

  /// No description provided for @photos.
  ///
  /// In ja, this message translates to:
  /// **'写真'**
  String get photos;

  /// No description provided for @noPhotos.
  ///
  /// In ja, this message translates to:
  /// **'写真はまだありません'**
  String get noPhotos;

  /// No description provided for @linkTarget.
  ///
  /// In ja, this message translates to:
  /// **'リンク先'**
  String get linkTarget;

  /// No description provided for @linkToLocation.
  ///
  /// In ja, this message translates to:
  /// **'栽培場所'**
  String get linkToLocation;

  /// No description provided for @linkToPlot.
  ///
  /// In ja, this message translates to:
  /// **'区画'**
  String get linkToPlot;

  /// No description provided for @linkToCrop.
  ///
  /// In ja, this message translates to:
  /// **'栽培'**
  String get linkToCrop;

  /// No description provided for @parentCrop.
  ///
  /// In ja, this message translates to:
  /// **'元の栽培'**
  String get parentCrop;

  /// No description provided for @environmentType.
  ///
  /// In ja, this message translates to:
  /// **'環境タイプ'**
  String get environmentType;

  /// No description provided for @envOutdoor.
  ///
  /// In ja, this message translates to:
  /// **'露地'**
  String get envOutdoor;

  /// No description provided for @envIndoor.
  ///
  /// In ja, this message translates to:
  /// **'室内'**
  String get envIndoor;

  /// No description provided for @envBalcony.
  ///
  /// In ja, this message translates to:
  /// **'ベランダ'**
  String get envBalcony;

  /// No description provided for @envRooftop.
  ///
  /// In ja, this message translates to:
  /// **'屋上'**
  String get envRooftop;

  /// No description provided for @coverType.
  ///
  /// In ja, this message translates to:
  /// **'被覆タイプ'**
  String get coverType;

  /// No description provided for @coverOpen.
  ///
  /// In ja, this message translates to:
  /// **'露地（覆いなし）'**
  String get coverOpen;

  /// No description provided for @coverGreenhouse.
  ///
  /// In ja, this message translates to:
  /// **'ハウス'**
  String get coverGreenhouse;

  /// No description provided for @coverTunnel.
  ///
  /// In ja, this message translates to:
  /// **'トンネル'**
  String get coverTunnel;

  /// No description provided for @coverColdFrame.
  ///
  /// In ja, this message translates to:
  /// **'フレーム'**
  String get coverColdFrame;

  /// No description provided for @soilType.
  ///
  /// In ja, this message translates to:
  /// **'土壌タイプ'**
  String get soilType;

  /// No description provided for @soilUnknown.
  ///
  /// In ja, this message translates to:
  /// **'不明'**
  String get soilUnknown;

  /// No description provided for @soilCite.
  ///
  /// In ja, this message translates to:
  /// **'粘土質'**
  String get soilCite;

  /// No description provided for @soilSilt.
  ///
  /// In ja, this message translates to:
  /// **'シルト質'**
  String get soilSilt;

  /// No description provided for @soilSandy.
  ///
  /// In ja, this message translates to:
  /// **'砂質'**
  String get soilSandy;

  /// No description provided for @soilLoam.
  ///
  /// In ja, this message translates to:
  /// **'壌土'**
  String get soilLoam;

  /// No description provided for @soilPeat.
  ///
  /// In ja, this message translates to:
  /// **'泥炭'**
  String get soilPeat;

  /// No description provided for @soilVolcanic.
  ///
  /// In ja, this message translates to:
  /// **'火山灰土'**
  String get soilVolcanic;

  /// No description provided for @getLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地を取得'**
  String get getLocation;

  /// No description provided for @locationSet.
  ///
  /// In ja, this message translates to:
  /// **'位置情報を設定しました'**
  String get locationSet;

  /// No description provided for @locationFailed.
  ///
  /// In ja, this message translates to:
  /// **'位置情報を取得できませんでした'**
  String get locationFailed;

  /// No description provided for @autoLinkNearest.
  ///
  /// In ja, this message translates to:
  /// **'現在地から自動選択'**
  String get autoLinkNearest;

  /// No description provided for @analyzing.
  ///
  /// In ja, this message translates to:
  /// **'写真を分析中…'**
  String get analyzing;

  /// No description provided for @plantDetected.
  ///
  /// In ja, this message translates to:
  /// **'植物を検出しました'**
  String get plantDetected;

  /// No description provided for @landscapeDetected.
  ///
  /// In ja, this message translates to:
  /// **'風景写真と判定しました'**
  String get landscapeDetected;

  /// No description provided for @noPlantDetected.
  ///
  /// In ja, this message translates to:
  /// **'植物は検出されませんでした'**
  String get noPlantDetected;

  /// No description provided for @identifyingPlant.
  ///
  /// In ja, this message translates to:
  /// **'作物を同定中…'**
  String get identifyingPlant;

  /// No description provided for @plantIdentified.
  ///
  /// In ja, this message translates to:
  /// **'推定: {name}'**
  String plantIdentified(String name);

  /// No description provided for @suggestedLink.
  ///
  /// In ja, this message translates to:
  /// **'自動提案: {target}'**
  String suggestedLink(String target);

  /// No description provided for @apiKeyNotSet.
  ///
  /// In ja, this message translates to:
  /// **'作物同定APIキーが未設定です'**
  String get apiKeyNotSet;

  /// No description provided for @plantIdProvider.
  ///
  /// In ja, this message translates to:
  /// **'植物同定'**
  String get plantIdProvider;

  /// No description provided for @plantIdProviderOff.
  ///
  /// In ja, this message translates to:
  /// **'オフ（同定しない）'**
  String get plantIdProviderOff;

  /// No description provided for @plantIdProviderOffDesc.
  ///
  /// In ja, this message translates to:
  /// **'小さな畑で不要な場合'**
  String get plantIdProviderOffDesc;

  /// No description provided for @plantIdProviderPlantId.
  ///
  /// In ja, this message translates to:
  /// **'Plant.id（直接API）'**
  String get plantIdProviderPlantId;

  /// No description provided for @plantIdProviderPlantIdDesc.
  ///
  /// In ja, this message translates to:
  /// **'植物特化DB、コスト低め（月200回無料）'**
  String get plantIdProviderPlantIdDesc;

  /// No description provided for @plantIdProviderServer.
  ///
  /// In ja, this message translates to:
  /// **'サーバー経由（APIキー不要）'**
  String get plantIdProviderServer;

  /// No description provided for @plantIdProviderServerDesc.
  ///
  /// In ja, this message translates to:
  /// **'FastAPIサーバーで処理、スマホ側の設定不要'**
  String get plantIdProviderServerDesc;

  /// No description provided for @plantIdApiKey.
  ///
  /// In ja, this message translates to:
  /// **'Plant.id APIキー'**
  String get plantIdApiKey;

  /// No description provided for @plantIdApiKeyHint.
  ///
  /// In ja, this message translates to:
  /// **'APIキーを入力'**
  String get plantIdApiKeyHint;

  /// No description provided for @serverUrl.
  ///
  /// In ja, this message translates to:
  /// **'サーバーURL'**
  String get serverUrl;

  /// No description provided for @serverUrlHint.
  ///
  /// In ja, this message translates to:
  /// **'https://grow-server.example.workers.dev'**
  String get serverUrlHint;

  /// No description provided for @serverToken.
  ///
  /// In ja, this message translates to:
  /// **'認証トークン'**
  String get serverToken;

  /// No description provided for @serverTokenHint.
  ///
  /// In ja, this message translates to:
  /// **'Bearer トークンを入力'**
  String get serverTokenHint;

  /// No description provided for @dataSync.
  ///
  /// In ja, this message translates to:
  /// **'データ同期'**
  String get dataSync;

  /// No description provided for @syncModeLocal.
  ///
  /// In ja, this message translates to:
  /// **'ローカルのみ'**
  String get syncModeLocal;

  /// No description provided for @syncModeLocalDesc.
  ///
  /// In ja, this message translates to:
  /// **'データはこの端末のみに保存'**
  String get syncModeLocalDesc;

  /// No description provided for @syncModeFastapi.
  ///
  /// In ja, this message translates to:
  /// **'FastAPI 同期'**
  String get syncModeFastapi;

  /// No description provided for @syncModeFastapiDesc.
  ///
  /// In ja, this message translates to:
  /// **'ローカル PC / 共有サーバーと同期'**
  String get syncModeFastapiDesc;

  /// No description provided for @syncModeCloudflare.
  ///
  /// In ja, this message translates to:
  /// **'Cloudflare 同期'**
  String get syncModeCloudflare;

  /// No description provided for @syncModeCloudflareDesc.
  ///
  /// In ja, this message translates to:
  /// **'サーバー経由でデータ・写真を同期'**
  String get syncModeCloudflareDesc;

  /// No description provided for @syncNow.
  ///
  /// In ja, this message translates to:
  /// **'今すぐ同期'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In ja, this message translates to:
  /// **'同期中…'**
  String get syncing;

  /// No description provided for @syncComplete.
  ///
  /// In ja, this message translates to:
  /// **'同期完了（取得: {pulled}件、送信: {pushed}件、写真: {photos}枚）'**
  String syncComplete(int pulled, int pushed, int photos);

  /// No description provided for @syncFailed.
  ///
  /// In ja, this message translates to:
  /// **'同期に失敗しました'**
  String get syncFailed;

  /// No description provided for @plotDetail.
  ///
  /// In ja, this message translates to:
  /// **'区画詳細'**
  String get plotDetail;

  /// No description provided for @cropsInPlot.
  ///
  /// In ja, this message translates to:
  /// **'この区画の栽培'**
  String get cropsInPlot;

  /// No description provided for @noCropsInPlot.
  ///
  /// In ja, this message translates to:
  /// **'この区画にはまだ栽培がありません'**
  String get noCropsInPlot;

  /// No description provided for @growthTimeline.
  ///
  /// In ja, this message translates to:
  /// **'成長タイムライン'**
  String get growthTimeline;

  /// No description provided for @createHomepage.
  ///
  /// In ja, this message translates to:
  /// **'ホームページを作成'**
  String get createHomepage;

  /// No description provided for @createHomepageDesc.
  ///
  /// In ja, this message translates to:
  /// **'この栽培の紹介ページを作成します'**
  String get createHomepageDesc;

  /// No description provided for @homepageComingSoon.
  ///
  /// In ja, this message translates to:
  /// **'ホームページ作成機能は準備中です'**
  String get homepageComingSoon;

  /// No description provided for @siteInfoFarm.
  ///
  /// In ja, this message translates to:
  /// **'農園情報'**
  String get siteInfoFarm;

  /// No description provided for @siteFarmName.
  ///
  /// In ja, this message translates to:
  /// **'農園名'**
  String get siteFarmName;

  /// No description provided for @siteFarmDesc.
  ///
  /// In ja, this message translates to:
  /// **'農園の紹介文'**
  String get siteFarmDesc;

  /// No description provided for @siteFarmLocation.
  ///
  /// In ja, this message translates to:
  /// **'所在地'**
  String get siteFarmLocation;

  /// No description provided for @siteFarmPolicy.
  ///
  /// In ja, this message translates to:
  /// **'栽培方針（例: 自然栽培）'**
  String get siteFarmPolicy;

  /// No description provided for @siteInfoCrops.
  ///
  /// In ja, this message translates to:
  /// **'掲載する作物'**
  String get siteInfoCrops;

  /// No description provided for @siteInfoSales.
  ///
  /// In ja, this message translates to:
  /// **'販売情報'**
  String get siteInfoSales;

  /// No description provided for @siteSalesDesc.
  ///
  /// In ja, this message translates to:
  /// **'販売方法の説明'**
  String get siteSalesDesc;

  /// No description provided for @siteSalesContact.
  ///
  /// In ja, this message translates to:
  /// **'連絡先（メール、電話など）'**
  String get siteSalesContact;

  /// No description provided for @siteGenerate.
  ///
  /// In ja, this message translates to:
  /// **'HTMLを生成'**
  String get siteGenerate;

  /// No description provided for @siteHtmlReady.
  ///
  /// In ja, this message translates to:
  /// **'HTMLが生成されました'**
  String get siteHtmlReady;

  /// No description provided for @siteCopyHtml.
  ///
  /// In ja, this message translates to:
  /// **'HTMLをコピー'**
  String get siteCopyHtml;

  /// No description provided for @siteDeploySection.
  ///
  /// In ja, this message translates to:
  /// **'Cloudflareに自動デプロイ'**
  String get siteDeploySection;

  /// No description provided for @siteDeployDesc.
  ///
  /// In ja, this message translates to:
  /// **'Cloudflare Pagesに直接デプロイします。アカウントIDとAPIトークンが必要です。'**
  String get siteDeployDesc;

  /// No description provided for @siteCfAccountId.
  ///
  /// In ja, this message translates to:
  /// **'Cloudflare Account ID'**
  String get siteCfAccountId;

  /// No description provided for @siteCfApiToken.
  ///
  /// In ja, this message translates to:
  /// **'Cloudflare API Token'**
  String get siteCfApiToken;

  /// No description provided for @siteCfProjectName.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト名（サイトURL）'**
  String get siteCfProjectName;

  /// No description provided for @siteDeploy.
  ///
  /// In ja, this message translates to:
  /// **'デプロイ'**
  String get siteDeploy;

  /// No description provided for @siteDeployDone.
  ///
  /// In ja, this message translates to:
  /// **'デプロイ完了'**
  String get siteDeployDone;

  /// No description provided for @searchRecords.
  ///
  /// In ja, this message translates to:
  /// **'記録を検索'**
  String get searchRecords;

  /// No description provided for @filterByActivity.
  ///
  /// In ja, this message translates to:
  /// **'作業で絞り込み'**
  String get filterByActivity;

  /// No description provided for @allActivities.
  ///
  /// In ja, this message translates to:
  /// **'すべての作業'**
  String get allActivities;

  /// No description provided for @searchHint.
  ///
  /// In ja, this message translates to:
  /// **'メモ、栽培名、場所名で検索'**
  String get searchHint;

  /// No description provided for @cultivationInfo.
  ///
  /// In ja, this message translates to:
  /// **'栽培情報'**
  String get cultivationInfo;

  /// No description provided for @seedPacketPhotos.
  ///
  /// In ja, this message translates to:
  /// **'種袋の写真'**
  String get seedPacketPhotos;

  /// No description provided for @readFromUrl.
  ///
  /// In ja, this message translates to:
  /// **'URLから栽培情報を取得'**
  String get readFromUrl;

  /// No description provided for @readFromSeedPhoto.
  ///
  /// In ja, this message translates to:
  /// **'種袋を撮影して読み取る'**
  String get readFromSeedPhoto;

  /// No description provided for @saveSeedPhoto.
  ///
  /// In ja, this message translates to:
  /// **'種袋の写真を保存（ローカル）'**
  String get saveSeedPhoto;

  /// No description provided for @cultivationReferences.
  ///
  /// In ja, this message translates to:
  /// **'参考情報'**
  String get cultivationReferences;

  /// No description provided for @addReference.
  ///
  /// In ja, this message translates to:
  /// **'参考URLを追加'**
  String get addReference;

  /// No description provided for @referenceUrl.
  ///
  /// In ja, this message translates to:
  /// **'URL'**
  String get referenceUrl;

  /// No description provided for @referenceTitle.
  ///
  /// In ja, this message translates to:
  /// **'タイトル'**
  String get referenceTitle;

  /// No description provided for @noReferences.
  ///
  /// In ja, this message translates to:
  /// **'参考情報はまだありません'**
  String get noReferences;

  /// No description provided for @readingUrl.
  ///
  /// In ja, this message translates to:
  /// **'URLから情報を読み取り中…'**
  String get readingUrl;

  /// No description provided for @readingImage.
  ///
  /// In ja, this message translates to:
  /// **'種袋を読み取り中…'**
  String get readingImage;

  /// No description provided for @readSuccess.
  ///
  /// In ja, this message translates to:
  /// **'栽培情報を取得しました'**
  String get readSuccess;

  /// No description provided for @readFailed.
  ///
  /// In ja, this message translates to:
  /// **'情報の取得に失敗しました'**
  String get readFailed;

  /// No description provided for @serverRequired.
  ///
  /// In ja, this message translates to:
  /// **'この機能にはサーバー設定が必要です'**
  String get serverRequired;

  /// No description provided for @autoFillConfirm.
  ///
  /// In ja, this message translates to:
  /// **'作物名・品種を自動入力しますか？'**
  String get autoFillConfirm;

  /// No description provided for @sowingPeriod.
  ///
  /// In ja, this message translates to:
  /// **'播種時期'**
  String get sowingPeriod;

  /// No description provided for @harvestPeriod.
  ///
  /// In ja, this message translates to:
  /// **'収穫時期'**
  String get harvestPeriod;

  /// No description provided for @spacing.
  ///
  /// In ja, this message translates to:
  /// **'株間'**
  String get spacing;

  /// No description provided for @seedDepth.
  ///
  /// In ja, this message translates to:
  /// **'播種深さ'**
  String get seedDepth;

  /// No description provided for @sunlight.
  ///
  /// In ja, this message translates to:
  /// **'日照'**
  String get sunlight;

  /// No description provided for @fertilizerInfo.
  ///
  /// In ja, this message translates to:
  /// **'施肥'**
  String get fertilizerInfo;

  /// No description provided for @cultivationTips.
  ///
  /// In ja, this message translates to:
  /// **'栽培のコツ'**
  String get cultivationTips;

  /// No description provided for @sourceUrl.
  ///
  /// In ja, this message translates to:
  /// **'取得元URL'**
  String get sourceUrl;

  /// No description provided for @cachedInfo.
  ///
  /// In ja, this message translates to:
  /// **'（共有データベースから取得）'**
  String get cachedInfo;

  /// No description provided for @skill.
  ///
  /// In ja, this message translates to:
  /// **'スキルズ'**
  String get skill;

  /// No description provided for @farmingMethod.
  ///
  /// In ja, this message translates to:
  /// **'農法'**
  String get farmingMethod;

  /// No description provided for @inheritFromSkill.
  ///
  /// In ja, this message translates to:
  /// **'スキルズ設定を使う'**
  String get inheritFromSkill;

  /// No description provided for @web.
  ///
  /// In ja, this message translates to:
  /// **'Web'**
  String get web;

  /// No description provided for @siteEasyPublish.
  ///
  /// In ja, this message translates to:
  /// **'かんたん公開'**
  String get siteEasyPublish;

  /// No description provided for @siteEasyPublishDesc.
  ///
  /// In ja, this message translates to:
  /// **'スキルズと栽培記録からサイトを自動作成し cowork.aiseed.dev に公開'**
  String get siteEasyPublishDesc;

  /// No description provided for @siteRequestSent.
  ///
  /// In ja, this message translates to:
  /// **'リクエストを送信しました。完了後メールでお知らせします。'**
  String get siteRequestSent;

  /// No description provided for @siteAdvancedMode.
  ///
  /// In ja, this message translates to:
  /// **'自分で作成（PC版）'**
  String get siteAdvancedMode;

  /// No description provided for @siteAdvancedModeDesc.
  ///
  /// In ja, this message translates to:
  /// **'HTMLを即時生成し、自分のCloudflare Pagesにデプロイ'**
  String get siteAdvancedModeDesc;

  /// No description provided for @siteAutoFilled.
  ///
  /// In ja, this message translates to:
  /// **'スキルズ設定から自動入力しました'**
  String get siteAutoFilled;

  /// No description provided for @siteEmail.
  ///
  /// In ja, this message translates to:
  /// **'通知メールアドレス'**
  String get siteEmail;

  /// No description provided for @siteUsername.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名（URL用、半角英数字）'**
  String get siteUsername;

  /// No description provided for @sitePublicUrl.
  ///
  /// In ja, this message translates to:
  /// **'公開URL'**
  String get sitePublicUrl;

  /// No description provided for @siteJobPending.
  ///
  /// In ja, this message translates to:
  /// **'処理待ち'**
  String get siteJobPending;

  /// No description provided for @siteJobProcessing.
  ///
  /// In ja, this message translates to:
  /// **'生成中…'**
  String get siteJobProcessing;

  /// No description provided for @siteJobDone.
  ///
  /// In ja, this message translates to:
  /// **'公開済み'**
  String get siteJobDone;

  /// No description provided for @siteJobError.
  ///
  /// In ja, this message translates to:
  /// **'エラー'**
  String get siteJobError;

  /// No description provided for @voiceInput.
  ///
  /// In ja, this message translates to:
  /// **'音声入力'**
  String get voiceInput;

  /// No description provided for @voiceInputStop.
  ///
  /// In ja, this message translates to:
  /// **'音声入力を停止'**
  String get voiceInputStop;

  /// No description provided for @voiceInputHint.
  ///
  /// In ja, this message translates to:
  /// **'話してください...'**
  String get voiceInputHint;

  /// No description provided for @voiceInputUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'音声入力は利用できません'**
  String get voiceInputUnavailable;

  /// No description provided for @qrCode.
  ///
  /// In ja, this message translates to:
  /// **'QRコード'**
  String get qrCode;

  /// No description provided for @qrCodeDesc.
  ///
  /// In ja, this message translates to:
  /// **'看板・値札・袋に貼って、ホームページに誘導'**
  String get qrCodeDesc;

  /// No description provided for @qrGenerate.
  ///
  /// In ja, this message translates to:
  /// **'QRコードを生成'**
  String get qrGenerate;

  /// No description provided for @qrRegenerate.
  ///
  /// In ja, this message translates to:
  /// **'再生成'**
  String get qrRegenerate;

  /// No description provided for @qrSave.
  ///
  /// In ja, this message translates to:
  /// **'画像を保存'**
  String get qrSave;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
