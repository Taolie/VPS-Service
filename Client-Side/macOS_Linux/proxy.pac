// Proxy Auto-Configuration (PAC) File
//
// 这个文件定义了浏览器和其他网络客户端应如何选择代理服务器来访问一个URL。
// 它可以实现智能分流：国内网站直连，国外网站走代理。

function FindProxyForURL(url, host) {

    // ---------------------- 配置区 ----------------------
    // SOCKS5代理服务器的地址和端口，必须和 vps_tunnel.sh 中的 LOCAL_PORT 一致。
    var proxy = "SOCKS5 127.0.0.1:1080; SOCKS 127.0.0.1:1080; DIRECT";
    // ----------------------------------------------------


    // ---------------------- 直连规则区 ----------------------
    // 如果访问的域名是以下列表中的，则直接连接，不走代理。
    // 你可以根据需要添加更多域名。格式为: "域名",
    // isPlainHostName(host) 用来匹配没有"."的本地主机名，例如 "localhost"
    // ----------------------------------------------------
    if (isPlainHostName(host)) {
        return "DIRECT";
    }

    // 常见国内域名后缀
    var direct_suffixes = [
        ".cn",
        ".com.cn",
        ".net.cn",
        ".org.cn",
        ".gov.cn",
        ".edu.cn",
    ];

    for (var i = 0; i < direct_suffixes.length; i++) {
        if (dnsDomainIs(host, direct_suffixes[i])) {
            return "DIRECT";
        }
    }

    // 常见国内网站域名 (你可以添加更多)
    var direct_domains = [
        "12306.cn",
        "163.com",
        "360.cn",
        "360buy.com",
        "36kr.com",
        "51.la",
        "abchina.com",
        "acfun.cn",
        "ali213.net",
        "alibaba.com",
        "alibabacloud.com",
        "alicdn.com",
        "alipay.com",
        "amap.com",
        "autohome.com.cn",
        "baidu.com",
        "baidupcs.com",
        "baidustatic.com",
        "bilibili.com",
        "boc.cn",
        "ccb.com",
        "cctv.com",
        "chinaz.com",
        "chinaso.com",
        "cmbchina.com",
        "cnbeta.com",
        "cnblogs.com",
        "csdn.net",
        "ctrip.com",
        "douban.com",
        "douyu.com",
        "dxy.cn",
        "eastmoney.com",
        "ele.me",
        "feng.com",
        "fun.tv",
        "geekpark.net",
        "gitee.com",
        "gtimg.com",
        "haosou.com",
        "huanqiu.com",
        "huya.com",
        "icbc.com.cn",
        "ifeng.com",
        "iqiyi.com",
        "jd.com",
        "jianshu.com",
        "kugou.com",
        "kuwo.cn",
        "le.com",
        "leiphone.com",
        "ludashi.com",
        "meituan.com",
        "mi.com",
        "mgtv.com",
        "mihoyo.com",
        "momo.com",
        "netease.com",
        "pconline.com.cn",
        "people.com.cn",
        "pingan.com",
        "qidian.com",
        "qihu.com",
        "qq.com",
        "qzone.com",
        "sandai.net",
        "sina.com",
        "sina.com.cn",
        "so.com",
        "sogou.com",
        "sohu.com",
        "suning.com",
        "taobao.com",
        "tencent.com",
        "tianyancha.com",
        "tmall.com",
        "tudou.com",
        "weibo.com",
        "xiami.com",
        "xinhuanet.com",
        "xunlei.com",
        "youku.com",
        "zhihu.com",
        "zjstv.com"
    ];

    for (var i = 0; i < direct_domains.length; i++) {
        if (dnsDomainIs(host, "." + direct_domains[i]) || host == direct_domains[i]) {
            return "DIRECT";
        }
    }


    // ---------------------- 代理规则 ----------------------
    // 如果以上规则都没有匹配到，则默认走代理。
    // ----------------------------------------------------
    return proxy;
}
