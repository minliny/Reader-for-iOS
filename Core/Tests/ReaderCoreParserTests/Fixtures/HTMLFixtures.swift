import Foundation

public enum HTMLFixtures {
    public static let simpleList = """
    <html>
        <body>
            <ul id="list">
                <li class="item">Item 1</li>
                <li class="item">Item 2</li>
                <li class="item">Item 3</li>
            </ul>
        </body>
    </html>
    """
    
    public static let nestedElements = """
    <div id="container">
        <div class="section">
            <h1>Section Title</h1>
            <p>Section content here.</p>
        </div>
        <div class="section">
            <h2>Another Section</h2>
            <p>More content here.</p>
            <a href="/page1" class="link">Link 1</a>
            <a href="/page2" class="link">Link 2</a>
        </div>
    </div>
    """
    
    public static let tocStructure = """
    <div class="toc">
        <ul>
            <li>
                <a href="/chapter1.html" class="toc-link">第一章 序章</a>
            </li>
            <li>
                <a href="/chapter2.html" class="toc-link">第二章 开始</a>
            </li>
            <li>
                <a href="/chapter3.html" class="toc-link">第三章 发展</a>
            </li>
        </ul>
    </div>
    """
    
    public static let withImages = """
    <article>
        <h1>Article Title</h1>
        <img src="/cover.jpg" alt="Cover Image" class="cover">
        <p>Article text...</p>
        <img src="/figure1.png" alt="Figure 1" class="figure">
    </article>
    """
    
    public static let innerHTMLTest = """
    <div id="outer">
        Outer text before
        <div id="inner">
            <span>Inner content</span>
        </div>
        Outer text after
    </div>
    """
}
