# 絶賛開発中です

## 開発メモ

- cloudforecastのおきかえ
- 少し良いハードの上で、1000台~3000台ぐらいのホストに対して1分更新を実現する
- インストールが面倒なのでSNMP.pmに依存しない
- agentからのpushと、monitoringサーバからのpullの両方をつかうハイブリッド構成
- rrdtoolを使うところは変わらない。大量にグラフを表示したいのでjsだとたぶんきつい
- SQLiteで頑張らない。MySQLを使って付属情報を保存

## しくみ

### workerは4種類

1. agentからのmetricsを受け取って、rrdとmysqlをアップデートするjob worker
2. metricsをpullして、rrdとmysqlをアップデートするjob worker
3. 1分毎に起動して2にキューを投げるwoker
4. web画面

### push


### pull

## MQTT Broker

RabbitMQとMosquittoが使える

http://mosquitto.org/

http://www.rabbitmq.com/mqtt.html

RabbitMQを使う予定

### RabbitMQ + MQTTのインストール

http://www.rabbitmq.com/install-rpm.html

CenOS6 だと

1.  EPELを有効にして、`yum install erlang`
2.  http://www.rabbitmq.com/install-rpm.html から最新版のURLをみて、`rpm -ivh` or `yum install`

```
$ rabbitmq-plugins enable rabbitmq_mqtt
$ service rabbitmq-server start
$ chkconfig rabbitmq-server on
```

# Agent

perlで書いてある。依存関係が含まれた1つのファイルとなっているのでコピーすれば動く

```
$ wget https://raw.githubusercontent.com/kazeburo/Kurado/master/agent_fatpack/kurado_agent
$ chmod +x kurado_agent
$ ./kurado_agent --help
```

metricsを表示して終了する

```
$ kurado_agent --dump
```

1分毎にサーバにmetricsを送る

```
$ kurado_agent --interval 1 --self ip.address.of.myself --mqtt 127.0.0.1:1887 --conf-d /etc/kurado_agent/conf.d
```


### オプション

- --self

    サーバのIPアドレス

- --conf-d

    拡張metricsの設定があるディレクトリ。設定ファイルは *.toml となる
 
 - --dump

    現在のmetricsを表示して終了

- --mqtt

    MQTT brokerサーバの IPアドレス:ポート
 
- --pidfile

    pidファイルのパス

- --interval

    metricsを送信する間隔(分)。デフォルトは1(分)

### 標準のmetrics

サンプル。標準で

- cpu
- disk io
- disk usage
- load average
- memory
- tcp established

などを取っている

tab切りで、`key[TAB]value[TAB]timestamp` 形式

```
base.metrics.cpu-guest-nice.derive	0	1404873350
base.metrics.cpu-guest.derive	0	1404873350
base.metrics.cpu-idle.derive	5689557	1404873350
base.metrics.cpu-iowait.derive	998	1404873350
base.metrics.cpu-irq.derive	894	1404873350
base.metrics.cpu-nice.derive	1	1404873350
base.metrics.cpu-softirq.derive	899	1404873350
base.metrics.cpu-steal.derive	0	1404873350
base.metrics.cpu-system.derive	13462	1404873350
base.metrics.cpu-user.derive	44682	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-read-ios.derive	38124	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-read-sectors.derive	1013426	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-write-ios.derive	311834	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-write-sectors.device	2462360	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-read-ios.derive	409	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-read-sectors.derive	3272	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-write-ios.derive	630	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-write-sectors.device	5040	1404873350
base.metrics.disk-io-sda-read-ios.derive	24676	1404873350
base.metrics.disk-io-sda-read-sectors.derive	1023692	1404873350
base.metrics.disk-io-sda-write-ios.derive	43704	1404873350
base.metrics.disk-io-sda-write-sectors.device	2467476	1404873350
base.metrics.disk-usage-mapper_VolGroup-lv_root-available.gauge	36329940	1404873350
base.metrics.disk-usage-mapper_VolGroup-lv_root-used.gauge	1487404	1404873350
base.metrics.loadavg-1.gauge	0.00	1404873350
base.metrics.loadavg-15.gauge	0.00	1404873350
base.metrics.loadavg-5.gauge	0.00	1404873350
base.metrics.memory-buffers.gauge	41582592	1404873350
base.metrics.memory-cached.gauge	218800128	1404873350
base.metrics.memory-free.gauge	68136960	1404873350
base.metrics.memory-inactive.gauge	143220736	1404873350
base.metrics.memory-swap-free.gauge	970604544	1404873350
base.metrics.memory-swap-total.gauge	973070336	1404873350
base.metrics.memory-swap-used.gauge	2465792	1404873350
base.metrics.memory-total.gauge	480718848	1404873350
base.metrics.memory-used.gauge	269361152	1404873350
base.metrics.processors.gauge	1	1404873350
base.metrics.tcp-established.gauge	3	1404873350
base.metrics.traffic-eth0-rxbytes.derive	146026292	1404873350
base.metrics.traffic-eth0-txbytes.derive	4955348	1404873350
base.meta.disk-io-devices	mapper_VolGroup-lv_root,mapper_VolGroup-lv_swap,sda	1404873350
base.meta.disk-usage-devices	mapper_VolGroup-lv_root	1404873350
base.meta.disk-usage-mapper_VolGroup-lv_root-mount	/	1404873350
base.meta.traffic-interfaces	eth0	1404873350
base.meta.uptime	57649	1404873350
base.meta.version	Linux version 2.6.32-431.el6.x86_64 (mockbuild@c6b8.bsys.dev.centos.org) (gcc version 4.4.7 20120313 (Red Hat 4.4.7-4) (GCC) ) #1 SMP Fri Nov 22 03:15:09 UTC 2013	1404873350
```

### 拡張metrics(plugin)

`--conf-d` で指定するディレクトリに TOML でplugin設定を書く
 
 sample.toml
 
 ```
[plugin.metrics.process]

pluginは



上のprocess pluginの出力は

```
process.metrics.fork.derive     39234   1404871619
```

となる

# サーバリスト設定

これから

# グラフ設定

これから

# pull設定

これから
