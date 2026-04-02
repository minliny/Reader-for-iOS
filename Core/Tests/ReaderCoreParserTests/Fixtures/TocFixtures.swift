import Foundation

public enum TocFixtures {
    public static let simpleLinks = """
    <ul>
        <li><a href="/chapter1.html">第一章</a></li>
        <li><a href="/chapter2.html">第二章</a></li>
        <li><a href="/chapter3.html">第三章</a></li>
    </ul>
    """
    
    public static let nestedToc = """
    <ul class="chapter-list">
        <li><a href="/vol1/ch1.html">第一章 序章</a></li>
        <li><a href="/vol1/ch2.html">第二章 开始</a></li>
        <li><a href="/vol2/ch1.html">第三章 发展</a></li>
        <li><a href="/vol2/ch2.html">第四章 高潮</a></li>
    </ul>
    """
    
    public static let relativeURLs = """
    <ul>
        <li><a href="ch1.html">第一章</a></li>
        <li><a href="ch2.html">第二章</a></li>
        <li><a href="../book/ch3.html">第三章</a></li>
    </ul>
    """
    
    public static let mixedTitles = """
    <ul>
        <li><a href="/c1.html">正文卷.第一章（上）</a></li>
        <li><a href="/c2.html">VIP章节.第二章【中】</a></li>
        <li><a href="/c3.html">免费章节.第三章[下]</a></li>
    </ul>
    """
    
    public static let emptyResult = """
    <div class="no-toc">
        <p>暂无目录</p>
    </div>
    """
    
    public static let selectorMiss = """
    <div class="wrong-class">
        <ul>
            <li><a href="/test.html">不会匹配到</a></li>
        </ul>
    </div>
    """
}
