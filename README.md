# Swift Matter Demo Samples

軽量な ESP 向け Matter デモ集です。
デバイス搭載のLEDやBME280
Swift ベースのサンプル（bme280 等）と、esp-matter を使ったプラットフォーム固有のサンプル（light-control 等）を含みます。

## 概要
- bme280: BME280 センサを読み取り、Matter の Temperature/Humidity/Pressure エンドポイントとして公開するサンプル（Swift）。
  - PressureはAppleのホームアプリからは確認できないため、アプリへの表示はTemperature/Humidityのみ
- light-control: esp-matter ベースのライト制御サンプル（CMake / ESP-IDF）。
- その他: 共通コンポーネントや Matter SDK のラッパー等。

## 前提
- ESP-IDF がインストール済みで、idf.py が利用可能であること。
- esp-matter リポジトリが存在し、環境変数 ESP_MATTER_PATH が設定されていること。
- 必要に応じて Swift ツールチェーンやクロスビルド環境（bme280 を Swift で組む場合）。

例:
- export IDF_PATH=~/esp/esp-idf
- export ESP_MATTER_PATH=~/esp/esp-matter

## 簡単なビルド手順（例: light-control）
1. 環境をセットアップ（ESP-IDF を source）:
   - . $IDF_PATH/export.sh
   - . $MATTER_PATH/export.sh
2. プロジェクトディレクトリへ移動:
   - cd light-control
3. ターゲットを設定(該当するesp32シリーズのデバイスを設定):
   - idf.py set-target esp32c6
4. ビルドとフラッシュ:
   - idf.py build
   - idf.py flash monitor

bme280 サンプルも同様に各ディレクトリで idf.py コマンドを使ってビルドできます（各サンプルの README や CMakeLists.txt を確認してください）。

## リポジトリ構成（抜粋）
- bme280/ — BME280 センサー用サンプル（Swift ソース等）
- light-control/ — ライト制御サンプル（esp-matter、CMake）
- components/, examples/, managed_components/ など — esp-matter や共通コンポーネント

## その他
- GPIO等の設定は使用デバイスことに設定を変更してください。
- 現状esp32c6デバイスのみ動作確認をしております。
- 他のデバイスで動作しない場合は、@tussi5969にご連絡ください🙇‍♂️