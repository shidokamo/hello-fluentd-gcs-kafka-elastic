# Hello Fluentd + Kafka + Elastic + GCS
GKE を用いたログ基盤のサンプルです。

## コンテナの構成
* Forwarder として、ダミーのログを出力し続けるロガーとサイドカーのFluentd
* Aggregator として、Fluentd
* メッセージキューとして Fluentd

## 動作
* Forwarder は、Aggregator にログ転送します。
* Aggregator は、標準出力にログを出力します。これはデバッグ用です。
* Aggregator は、GCS に定期的にログをアップロードします。
* Aggregator は、Kafka にログをパブリッシュします。
* Aggregator は、Elastic の index にログを入力します。

## Requirements (イメージ）
事前に、以下の２つのイメージをビルドしておく必要があります。

* [fluentd-image](https://github.com/shidokamo/fluentd-image)
* [test-logger-image](https://github.com/shidokamo/test-logger-image)

ローカルにイメージを保存するか、もしくはクラウドレポジトリに登録しておく必要があります。
gcr.io のコンテナレジストリ以外を使う場合は、イメージのパスを書き換えてください。

また、Elasticsearch のホストを用意しておく必要があります。

## Requirements （サービスアカウントの設定）
`aggregator` という名前で、サービスアカウントを発行し、ストレージオブジェクトの作成権限を与えてください。
このアカウントが適切に設定されていないと、GCS へのバケット作成に失敗し、エラーとなります。

## Requirements （Helm）
Helm をインストールしておく必要があります。

## ネットワークの準備
以下のコマンドで、新しいサブネットと２つのセカンダリ範囲を作成してください。
もし、`10.1.0.0/16` をすでに使用している場合は、別の範囲を指定してください。

```
gcloud compute networks subnets create subnet-a \
  --network default \
  --range 10.1.0.0/16 \
  --secondary-range pod-range=172.16.128.0/19,svc-range=172.16.160.0/22
```

その後、172.16.128.0/19 をソースとする全ての通信を許可するようにファイアウォールを更新してください。

## 手順
クラスタを作成します。

```
make setup-cluster
```

クラスタに Helm の Tiller をインストールします。

```
make setup-helm
```

サービスアカウント用の鍵情報を作成します。

```
make setup-service-account
```

もしくは、ここまでの手順を一括して

```
make setup
```

Helm をインストールしてから有効になるまでしばらく時間がかかるので待ちます。
その後、Kafka をデプロイします。Kafka は起動にかなり時間がかかります。

```
make kafka
```

## アプリケーションのデプロイ
```
make
```

## Forwarder の動作
Pod 内に2つのコンテナを起動します。
* logger コンテナは、`/var/log/app.log` へログローテートを行いながらログを出力し続けます。
* sidecar コンテナは、`/var/log/app.log` を監視し、得たログを Aggregator に Forward します。
* Pod は 3 つ起動されます。

## Forwarder の動作
Pod 内に1つのコンテナを起動します。
* aggregator コンテナは、GCS へローテートを行いながらログを出力し続けます。
* aggregator コンテナは、標準出力へも同時に出力を行います。

## Aggregator のログの確認
Fluentd の Aggregator コンテナの出力結果は以下のように確認できます。
Pod の名前は、`kubectl get pod` で得たものに置き換えてください。

```
kubectl logs aggregator-59cb4fdbc6-6kd4s
```

## Kafka の Topic の確認
Kafka の Broker のエンドポイントを以下のようにして探してください。
```
make check-endpoint
```

Kafkacat で NodePort から Topic を読み込んで、ログが流れていることを確認してください。
```
kafkacat -b YOUR_ENDPOINT_IP -C -t logger
```

## GCS のバケットの確認
GCS に、PROJECT_NAME-aggregator という名前のバケットができており、ログが出力されているのを
確認してください。

```
make check-gcs
```

## Elasticsearch の確認
インデックスが作成されているかどうか確認してください。名前は、`logstash-*` になります。

## クリーンナップ
```
make clean-all
```
