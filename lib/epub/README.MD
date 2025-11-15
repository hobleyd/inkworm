My approach to epub parsing is to parse the HTML and CSS into HtmlContent; either Text or Image content
with a ParagraphBreak to indicate new blocks.

Once we have the content parsed with the correct CSS styling tagged against it, we'll turn it into
LineElements, either Word or Image configured for easy painting onto a canvas. This way we can properly
support dropcaps and other advanced features we see in Books.

The eEpubChapter class will loop over the chapter and create pages (based on Font Size) with all the 
LineElements required to fill the page.

The PageRenderer will loop over the Page required and pain the LineElements into the Canvas.