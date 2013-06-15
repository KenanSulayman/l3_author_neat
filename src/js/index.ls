function derive-primary-author($node)
  by-author = {}
  $node.children 'span' .each ->
    $this = $ this
    allclass = $this.attr 'class' .split ' '
    for spanclass in allclass when spanclass is /^author/
      length = $this.text!length
      # the length of the span
      by-author[spanclass] ?= 0
      by-author[spanclass] += length
  # mPA = most prolific author
  mPA = 0
  authorClass = null
  for author, value of by-author
    if value > mPA
      mPA = value
      authorClass = author
  return authorClass

function toggle-author($node, prefix, authorClass)
  has-class = false
  my-class = "#prefix-#authorClass"
  attr = $node.attr(\class) ? ''
  for c in attr.split ' ' when c.indexOf(prefix) is 0
    if c is my-class
      has-class = true
    else
      $node.removeClass c
  return false if has-class
  $node.addClass my-class
  return true

# enter is pressed and there are likely new lines so should work through them
hasEnter = false

authorViewUpdate = ($node) ->
  lineNumber = $node.index! + 1
  # dont process lines we dont know the number of.
  return false unless lineNumber

  authorClass = false
  authorLines[lineNumber] = null
  $sidedivinner = $ 'iframe[name="ace_outer"]' .contents!find '#sidedivinner'
  $authorContainer = $sidedivinner.find "div:nth-child(#lineNumber)"

  if $node.text!length > 0
    authorClass = authorLines[lineNumber] = derive-primary-author $node
  else
    $authorContainer.addClass "primary-author-none"

  if authorClass
    toggle-author $node, "primary", authorClass
    authorChanged = toggle-author $authorContainer, "primary", authorClass
    prev = lineNumber - 1
    next = lineNumber + 1
    # this line shouldn't have any author name.
    # Does the next line have the same author?
    if authorLines[next] is authorClass
      $nextAuthorContainer = $sidedivinner.find "div:nth-child(#next)"
        ..addClass \concise
      # does the previous line have the same author?
      prevLineSameAuthor = authorLines[prev] is authorClass
      if not prevLineSameAuthor
        $authorContainer.removeClass \concise
    else
      # write the author name
      # Has the author changed, if so we need to uipdate the UI anyways..
      prevLineAuthorClass = authorLines[prev]
      if authorClass isnt prevLineAuthorClass and not authorChanged
        $authorContainer.removeClass \concise
      else
        # write the author name
        $authorContainer.addClass \concise
    # If the authorClass is not the same as the previous line author class and the author had not changed
    $sidedivinner.find "div:nth-child(#lineNumber)"
      .attr 'title', 'Line number ' + lineNumber

  if hasEnter
    next = $node.next!
    if next.length
      authorViewUpdate next
    else
      hasEnter := false

# add a hover for line numbers
fadeColor = (colorCSS, fadeFrac) ->
  color = colorutils.css2triple colorCSS
  colorutils.triple2css colorutils.blend color, [1 1 1 ], fadeFrac

getAuthorClassName = (author) ->
  'author-' + author.replace /[^a-y0-9]/g, (c) ->
    if c is '.'
      '-'
    else
      'z' + c.charCodeAt(0) + 'z'


# XXX: this should be just injected with aceEditorCSS. investigate if we can inject outer
var init
function outerInit(outerDynamicCSS)
  outerDynamicCSS.selectorStyle '#sidedivinner > div.primary-author-none'
    ..border-right = 'solid 0px '
    ..padding-right = '5px'
  outerDynamicCSS.selectorStyle '#sidedivinner > div.concise::before'
    ..content = "' '"
  outerDynamicCSS.selectorStyle '#sidedivinner > div'
    ..font-size = '0px'
  outerDynamicCSS.selectorStyle '#sidedivinner > div::before'
    ..font-size = 'initial'
    ..text-overflow = 'ellipsis'
    ..overflow = 'hidden'
  init := true

export function aceSetAuthorStyle(name, context)
  { dynamicCSS, outerDynamicCSS, parentDynamicCSS, info, author, authorSelector } = context
  outerInit outerDynamicCSS unless init

  if info
    return 1 unless color = info.bgcolor
    authorClass = getAuthorClassName author
    authorName = authorNameAndColorFromAuthorId author .name
    authorSelector = ".authorColors span.#authorClass"
    # author style
    dynamicCSS.selectorStyle authorSelector
      ..border-bottom = "2px solid #color"
    parentDynamicCSS.selectorStyle authorSelector
      ..border-bottom = "2px solid #color"
    # primary author override
    dynamicCSS.selectorStyle ".authorColors .primary-#authorClass .#authorClass"
      ..border-bottom = '0px'
    # primary author style on left
    outerDynamicCSS.selectorStyle "\#sidedivinner > div.primary-#authorClass"
      ..border-right = "solid 5px #{color}"
      ..padding-right = '5px'
    outerDynamicCSS.selectorStyle "\#sidedivinner > div.primary-#authorClass::before"
      ..content = "'#{ authorNameAndColorFromAuthorId author .name }'"

  else
    dynamicCSS.removeSelectorStyle authorSelector
    parentDynamicCSS.removeSelectorStyle authorSelector
  1

authorNameAndColorFromAuthorId = (authorId) ->
  myAuthorId = pad.myUserInfo.userId
  # It could always be me..
  if myAuthorId is authorId
    return do
      name: 'Me'
      color: pad.myUserInfo.colorId
  # Not me, let's look up in the DOM
  authorObj = {}
  $ '#otheruserstable > tbody > tr' .each ->
    if authorId is ($ this).data 'authorid'
      $ this
        ..find '.usertdname' .each ->
          authorObj.name = $ this .text! || 'Unknown Author'
        ..find '.usertdswatch > div' .each ->
          authorObj.color = $ this .css 'background-color'
      authorObj
  # Else go historical
  if not authorObj or not authorObj.name
    authorObj = clientVars.collab_client_vars.historicalAuthorData[authorId]
  # Try to use historical data
  authorObj or do
    name: 'Unknown Author'
    color: '#fff'

authorLines = {}

# When the DOM is edited
export function acePostWriteDomLineHTML(hook_name, args, cb)
  # avoid pesky race conditions
  setTimeout (-> authorViewUpdate $ args.node), 200ms

# on an edit
export function aceKeyEvent(hook_name, {evt}:context, cb)
  if evt.keyCode is 13 and evt.type is \keyup
    hasEnter := true

# on an edit
export function aceEditEvent(hook_name, {callstack}:context, cb)
  return unless callstack.type is \setWraps
  $ 'iframe[name="ace_outer"]' .contents!
    # no need for padding when we use borders
    ..find '#sidediv' .css 'padding-right': '0px'
    # set max width to 180
    ..find '#sidedivinner' .css do
      'max-width': '180px'
      overflow: 'hidden'

# For those who need them (< IE 9), add support for CSS functions
isStyleFuncSupported = CSSStyleDeclaration::getPropertyValue?

if not isStyleFuncSupported
  CSSStyleDeclaration::getPropertyValue = (a) -> @getAttribute a
  CSSStyleDeclaration::setProperty = (styleName, value, priority) ->
    @setAttribute styleName, value
    priority = if typeof priority isnt 'undefined' then priority else ''
    if not (priority is '')
      rule = new RegExp (RegExp.escape styleName) + '\\s*:\\s*' + RegExp.escape value + '(\\s*;)?', 'gmi'
      @cssText = @cssText.replace rule, styleName + ': ' + value + ' !' + priority + ';'
  # Add priority manually
  CSSStyleDeclaration::removeProperty = (a) -> @removeAttribute a
  CSSStyleDeclaration::getPropertyPriority = (styleName) ->
    rule = new RegExp (RegExp.escape styleName) + '\\s*:\\s*[^\\s]*\\s*!important(\\s*;)?', 'gmi'
    if rule.test @cssText
      'important'
    else
      ''

# Escape regex chars with \
RegExp.escape = (text) -> text.replace /[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&'
