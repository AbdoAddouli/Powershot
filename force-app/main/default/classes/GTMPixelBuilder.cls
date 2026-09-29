/**
 * GTMPixelBuilder
 * ================
 * Generates the HTML/JavaScript snippets for third-party advertising pixels.
 *
 * Each method returns a complete <script> block (and optional <noscript> fallback)
 * for a specific platform's tracking pixel. These snippets are injected into GTM
 * as Custom HTML tags during provisioning.
 *
 * Supported platforms: TikTok, Snapchat, LinkedIn.
 */
public with sharing class GTMPixelBuilder {

    /**
     * Returns the TikTok Pixel base code snippet.
     * Loads the TikTok analytics SDK, initializes with pixelId, fires ttq.page().
     *
     * @param pixelId The TikTok Pixel ID from GTM_Config__c.TikTok_Pixel_ID__c.
     */
    public static String buildTikTokPixelHtml(String pixelId) {
        return '<script>\n' +
            '!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];' +
            'ttq.methods=["page","track","identify","instances","debug","on","off","once","ready",' +
            '"alias","group","enableCookie","disableCookie","holdConsent","revokeConsent","grantConsent"],' +
            'ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))};' +
            'for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);' +
            'ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)' +
            'ttq.setAndDefer(e,ttq.methods[n]);return e},' +
            'ttq.load=function(e,n){var r="https://analytics.tiktok.com/i18n/pixel/events.js",' +
            'o=n&&n.partner;ttq._i=ttq._i||{},ttq._i[e]=[],ttq._i[e]._u=r,' +
            'ttq._t=ttq._t||{},ttq._t[e]=+new Date,ttq._o=ttq._o||{},ttq._o[e]=n||{};' +
            'n=document.createElement("script");n.type="text/javascript",n.async=!0,' +
            'n.src=r+"?sdkid="+e+"&lib="+t;' +
            'e=document.getElementsByTagName("script")[0];e.parentNode.insertBefore(n,e)};' +
            'ttq.load(\'' + pixelId + '\');ttq.page();}(window,document,\'ttq\');\n' +
            '</script>';
    }

    /**
     * Returns the Snapchat Pixel base code snippet.
     * Loads the Snapchat events SDK, initializes with pixelId, fires PAGE_VIEW.
     *
     * @param pixelId The Snapchat Pixel ID from GTM_Config__c.Snapchat_Pixel_ID__c.
     */
    public static String buildSnapchatPixelHtml(String pixelId) {
        return '<script>\n' +
            '(function(e,t,n){if(e.snaptr)return;var a=e.snaptr=function(){' +
            'a.handleRequest?a.handleRequest.apply(a,arguments):a.queue.push(arguments)};' +
            'a.queue=[];var s="script";r=t.createElement(s);r.async=!0;' +
            'r.src=n;var u=t.getElementsByTagName(s)[0];' +
            'u.parentNode.insertBefore(r,u);})(window,document,\n' +
            '\'https://sc-static.net/scevent.min.js\');\n' +
            'snaptr(\'init\', \'' + pixelId + '\');\n' +
            'snaptr(\'track\', \'PAGE_VIEW\');\n' +
            '</script>';
    }

    /**
     * Returns the LinkedIn Insight Tag base code.
     * Sets _linkedin_partner_id, loads the insight.min.js SDK, and includes
     * a noscript fallback image pixel for non-JS environments.
     *
     * @param partnerId The LinkedIn Partner ID from GTM_Config__c.LinkedIn_Partner_ID__c.
     */
    public static String buildLinkedInInsightHtml(String partnerId) {
        return '<script type="text/javascript">\n' +
            '_linkedin_partner_id = "' + partnerId + '";\n' +
            'window._linkedin_data_partner_ids = window._linkedin_data_partner_ids || [];\n' +
            'window._linkedin_data_partner_ids.push(_linkedin_partner_id);\n' +
            '</script>\n' +
            '<script type="text/javascript">\n' +
            '(function(l){if(!l){window.lintrk=function(a,b){window.lintrk.q.push([a,b])};' +
            'window.lintrk.q=[]}' +
            'var s=document.getElementsByTagName("script")[0];' +
            'var b=document.createElement("script");' +
            'b.type="text/javascript";b.async=true;' +
            'b.src="https://snap.licdn.com/li.lms-analytics/insight.min.js";' +
            's.parentNode.insertBefore(b,s);})(window.lintrk);\n' +
            '</script>\n' +
            '<noscript>\n' +
            '<img height="1" width="1" style="display:none;" alt="" ' +
            'src="https://px.ads.linkedin.com/collect/?pid=' + partnerId + '&fmt=gif" />\n' +
            '</noscript>';
    }
}