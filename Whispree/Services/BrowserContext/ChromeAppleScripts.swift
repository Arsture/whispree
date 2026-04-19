import Foundation

/// Chrome 제어용 AppleScript 템플릿 모음.
///
/// JS 코드는 한 줄로 minify해서 AppleScript 문자열 리터럴 안에 embed.
/// "Apple Events로부터 JavaScript 허용" 비활성 시 `on error` 블록이 조용히 실패 처리.
enum ChromeAppleScripts {

    /// document.activeElement의 CSS selector + 커서 위치를 함께 캡처.
    /// - selector: #id로 끝나거나 body 방향 nth-of-type 체인.
    /// - type: "input" (selectionStart/End 사용) | "ce" (contenteditable — root 기준 문자 offset) | "".
    /// - start/end: input은 selectionStart/selectionEnd. ce는 TreeWalker로 환산한 문자 offset.
    /// 반환 포맷: `selector|::|type|::|start|::|end` (빈 input = "")
    private static let captureElementJS = "(function(){var el=document.activeElement;if(!el||el===document.body)return '';var target=el;var parts=[];while(el&&el.nodeType===1&&el!==document.body){var name=el.nodeName.toLowerCase();if(el.id){parts.unshift('#'+el.id);break;}var idx=1,sib=el;while((sib=sib.previousElementSibling)){if(sib.nodeName===el.nodeName)idx++;}parts.unshift(name+':nth-of-type('+idx+')');el=el.parentNode;}var selector=parts.join(' > ');var type='',start=0,end=0;if(typeof target.selectionStart==='number'&&typeof target.value==='string'){type='input';start=target.selectionStart||0;end=target.selectionEnd||0;}else if(target.isContentEditable){type='ce';var sel=window.getSelection();if(sel&&sel.rangeCount>0){var r=sel.getRangeAt(0);var pre=document.createRange();pre.selectNodeContents(target);try{pre.setEnd(r.startContainer,r.startOffset);start=pre.toString().length;pre.setEnd(r.endContainer,r.endOffset);end=pre.toString().length;}catch(_){start=0;end=0;}}}return selector+'|::|'+type+'|::|'+start+'|::|'+end;})()"

    /// 활성 Chrome 탭의 window idx | tab idx | tab id | URL을 "|::|"로 구분 반환.
    /// front window 없으면 "".
    static let captureActiveTab = """
    tell application "Google Chrome"
        if not (exists front window) then return ""
        set aWin to front window
        set tabIdx to active tab index of aWin
        set aTab to active tab of aWin
        set tabID to id of aTab
        set tabURL to URL of aTab
        return "1|::|" & (tabIdx as string) & "|::|" & (tabID as string) & "|::|" & tabURL
    end tell
    """

    /// document.activeElement의 selector + 커서 위치를 JS 주입으로 계산.
    /// 반환: `selector|::|type|::|start|::|end` (JS 미허용/실패 시 "").
    static let captureActiveElement: String = {
        let escaped = escapeForAppleScript(captureElementJS)
        return """
        tell application "Google Chrome"
            if not (exists front window) then return ""
            set jsCode to "\(escaped)"
            try
                set sel to execute (active tab of front window) javascript jsCode
                return sel
            on error
                return ""
            end try
        end tell
        """
    }()

    /// 저장된 tabID로 탭 우선 검색 → 실패 시 URL 매칭 fallback.
    /// 탭 활성화 + 윈도우 최전면. 성공 "ok", 못 찾으면 "notfound", 창 없으면 "nowindow".
    static func restoreTab(tabID: Int, fallbackURL: String) -> String {
        let escURL = escapeForAppleScript(fallbackURL)
        return """
        tell application "Google Chrome"
            activate
            if (count of windows) = 0 then return "nowindow"
            set targetID to \(tabID)
            set targetURL to "\(escURL)"
            set winCount to count of windows
            repeat with w from 1 to winCount
                set aWin to window w
                set tabCount to count of tabs of aWin
                repeat with t from 1 to tabCount
                    if (id of tab t of aWin) = targetID then
                        set active tab index of aWin to t
                        set index of aWin to 1
                        return "ok"
                    end if
                end repeat
            end repeat
            repeat with w from 1 to winCount
                set aWin to window w
                set tabCount to count of tabs of aWin
                repeat with t from 1 to tabCount
                    if (URL of tab t of aWin) = targetURL then
                        set active tab index of aWin to t
                        set index of aWin to 1
                        return "ok"
                    end if
                end repeat
            end repeat
            return "notfound"
        end tell
        """
    }

    /// 활성 탭에서 selector 엘리먼트에 focus + **캡처 당시 커서 위치를 그대로 복원**.
    /// - input/textarea: `setSelectionRange(start, end)`. value 길이를 초과하면 clamp.
    /// - contenteditable: TreeWalker로 text node + offset 환산 후 `Range.setStart/setEnd`.
    /// 캡처 시점과 DOM이 달라져 offset이 유효하지 않으면 텍스트 노드 끝으로 fallback.
    /// JS 미허용 시 조용히 실패 ("fail" 반환, 탭 복원만 수행된 상태 유지).
    static func focusElement(selector: String, type: String, start: Int, end: Int) -> String {
        let escSelector = escapeForJSSingleQuotedString(selector)
        let escType = escapeForJSSingleQuotedString(type)
        let js = "try{var e=document.querySelector('\(escSelector)');if(!e)throw 0;e.focus();var t='\(escType)',s=\(start),ed=\(end);if(t==='input'){if(typeof e.setSelectionRange==='function'){var vl=((typeof e.value==='string')?e.value:'').length;e.setSelectionRange(Math.min(s,vl),Math.min(ed,vl));}}else if(t==='ce'){function fp(root,tg){var w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT,null);var rem=tg,n=w.nextNode(),last=null;while(n){var ln=n.nodeValue.length;if(rem<=ln)return{n:n,o:rem};rem-=ln;last=n;n=w.nextNode();}return last?{n:last,o:last.nodeValue.length}:{n:root,o:0};}var sp=fp(e,s),ep=fp(e,ed);var r=document.createRange();r.setStart(sp.n,sp.o);r.setEnd(ep.n,ep.o);var sl=window.getSelection();if(sl){sl.removeAllRanges();sl.addRange(r);}}}catch(_){}"
        let escJS = escapeForAppleScript(js)
        return """
        tell application "Google Chrome"
            if not (exists front window) then return "nowindow"
            set jsCode to "\(escJS)"
            try
                execute (active tab of front window) javascript jsCode
                return "ok"
            on error
                return "fail"
            end try
        end tell
        """
    }

    // MARK: - Escaping

    /// AppleScript 문자열 리터럴 내부에 embed될 문자열을 escape.
    /// `\` → `\\`, `"` → `\"`. 순서 중요 (백슬래시 먼저).
    private static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// JS single-quoted string 내부에 embed될 문자열을 escape.
    private static func escapeForJSSingleQuotedString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "'", with: "\\'")
    }
}
