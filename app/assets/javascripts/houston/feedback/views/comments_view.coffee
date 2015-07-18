KEY =
  TAB: 9
  RETURN: 13
  ESC: 27
  UP: 38
  DOWN: 40

class Houston.Feedback.CommentsView extends Backbone.View
  template: HandlebarsTemplates['houston/feedback/comments/index']
  renderComment: HandlebarsTemplates['houston/feedback/comments/show']
  renderEditComment: HandlebarsTemplates['houston/feedback/comments/edit']
  renderEditMultiple: HandlebarsTemplates['houston/feedback/comments/edit_multiple']
  renderSearchReport: HandlebarsTemplates['houston/feedback/comments/report']
  renderImportModal: HandlebarsTemplates['houston/feedback/comments/import']
  renderDeleteImportedModal: HandlebarsTemplates['houston/feedback/comments/delete_imported']
  renderNewCommentModal: HandlebarsTemplates['houston/feedback/comments/new']
  renderTagCloud: HandlebarsTemplates['houston/feedback/comments/tags']
 
  events:
    'submit #search_feedback': 'search'
    'focus .feedback-search-result': 'resultFocused'
    'mousedown .feedback-search-result': 'resultClicked'
    'mouseup .feedback-search-result': 'resultReleased'
    'keydown': 'keydown'
    'keydown #q': 'keydownSearch'
    'click .feedback-comment-close': 'selectNone'
    'click .feedback-remove-tag': 'removeTag'
    'keydown .feedback-new-tag': 'keydownNewTag'
    'click .btn-delete': 'deleteComments'
    'click .btn-edit': 'editCommentText'
    'click .btn-save': 'saveCommentText'
    'keydown .feedback-text textarea': 'keydownCommentText'
    'click #toggle_extra_tags_link': 'toggleExtraTags'
    'click .feedback-tag-cloud > .feedback-tag': 'clickTag'
    'click .btn-read': 'toggleRead'
  
  initialize: ->
    @$results = @$el.find('#results')
    @comments = @options.comments
    @tags = @options.tags
    
    $('#import_csv_field').change (e)->
      $(e.target).closest('form').submit()
      
      # clear the field so that if we select the same
      # file again, we get another 'change' event.
      $(e.target).val('').attr('type', 'text').attr('type', 'file')
    
    $('#feedback_csv_upload_target').on 'upload:complete', (e, headers)=>
      @promptToImportCsv(headers)
    
    $('#new_feedback_button').click =>
      @newFeedback()
    
    if @options.infiniteScroll
      new InfiniteScroll
        load: ($what)=>
          promise = new $.Deferred()
          @offset += 50
          promise.resolve @template
            comments: (comment.toJSON() for comment in @comments.slice(@offset, @offset + 50))
          promise
  
  
  
  resultFocused: (e)->
    $('.feedback-search-result.anchor').removeClass('anchor')
    $result = $(e.target)
    $result.addClass('anchor')
    
    return if @resultIsBeingClicked
    
    @select e.target, 'new' unless $result.is('.selected')
  
  resultClicked: (e)->
    @resultIsBeingClicked = true
    @select e.target, @mode(e)
  
  resultReleased: (e)->
    @resultIsBeingClicked = false
    @focusEditor()
  
  mode: (e)->
    return 'toggle' if e.metaKey or e.ctrlKey
    return 'lasso' if e.shiftKey
    'new'
  
  select: (comment, mode)->
    $el = @$comment(comment)
    
    $anchor = $('.feedback-search-result.anchor')
    mode = 'new' if mode is 'lasso' and $anchor.length is 0
    
    switch mode
      when 'toggle'
        $el.toggleClass('selected')
        $el.focus() if $el.hasClass('selected') and !$el.is(':focus')
        
      when 'lasso'
        $range = @$results.children().between($anchor, $el)
        $range.addClass('selected')
        
      else
        @$selection().removeClass('selected')
        $el.addClass('selected')
        $el.focus() unless $el.is(':focus')
    
    @selectedComments = (@comments.get(id) for id in @selectedIds())
    @$el.toggleClass 'feedback-selected', @selectedComments.length > 0
    @editSelected()

  $selection: ->
    @$el.find('.feedback-search-result.selected')

  selectedIds: ->
    $(el).attr('data-id') for el in @$selection()

  selectedId: ->
    ids = @selectedIds()
    throw "Expected only one comment to be selected, but there are #{ids.length}" unless ids.length is 1
    ids[0]

  selectPrev: (mode)->
    $prev = @$selection().first().prev('.feedback-search-result')
    if $prev and $prev.length > 0
      @select $prev, mode
    else if mode is 'new'
      @focusSearch()

  selectNext: (mode)->
    $next = @$selection().last().next('.feedback-search-result')
    if $next and $next.length > 0
      @select $next, mode

  selectNone: ->
    @select null, 'new'

  $comment: (comment)->
    return $() unless comment
    return @$comment comment[0] if _.isArray(comment)
    return @$comment comment.target if comment.target
    return $("#comment_#{comment.id}") if comment.constructor is Houston.Feedback.Comment
    $(comment).closest('.feedback-search-result')

  keydown: (e)->
    switch e.keyCode
      when KEY.UP then @selectPrev(@mode(e))
      when KEY.DOWN then @selectNext(@mode(e))
      when KEY.ESC then @focusSearch()

  keydownSearch: (e)->
    if e.keyCode is KEY.DOWN
      e.stopImmediatePropagation()
      @select @$el.find('.feedback-search-result:first'), 'new'

  search: (e)->
    return unless history.pushState

    e.preventDefault() if e
    search = $('#search_feedback').serialize()
    url = window.location.pathname + '?' + search
    xlsxHref = window.location.pathname + '.xlsx?' + search
    history.pushState({}, '', url)
    $('#excel_export_button').attr('href', xlsxHref)
    start = new Date()
    $.getJSON url, (comments)=>
      @selectNone()
      @comments = new Houston.Feedback.Comments(comments, parse: true)
      @searchTime = (new Date() - start)
      @render()

  

  render: ->
    @offset = 0
    html = @template(comments: (comment.toJSON() for comment in @comments.slice(0, 50)))
    @$results.html(html)

    @$el.find('#search_report').html @renderSearchReport
      results: @comments.length
      searchTime: @searchTime

    tags = @comments.countTags()
    $('#tags_report').html @renderTagCloud
      topTags: tags.slice(0, 5)
      extraTags: tags.slice(5)

    $('#feedback_edit').affix(offset: {top: 192})

    @focusSearch()

  focusSearch: ->
    window.scrollTo(0, 0)
    $('#search_feedback input').focus().select()

  editSelected: ->
    if @selectedComments.length is 1
      @editComment @selectedComments[0]
    else if @selectedComments.length > 1
      @editMultiple @selectedComments
    else
      @editNothing()

  editComment: (comment)->
    if @timeoutId
      window.clearTimeout(@timeoutId)
      @timeoutId = null

    if comment.isUnread()
      @timeoutId = window.setTimeout =>
        @markAsRead comment, ->
          $('.feedback-comment.feedback-edit-comment .btn-read').addClass('active')
      , 1500

    $('#feedback_edit').html @renderEditComment(comment.toJSON())
    $('#feedback_edit .uploader').supportImages()
    @focusEditor()

  editMultiple: (comments)->
    context = 
      count: comments.length
      permissions:
        destroy: _.all comments, (comment)-> comment.get('permissions').destroy
      tags: []
      read: _.all comments, (comment)-> comment.get('read')
    
    tags = (comment.get('tags') for comment in comments).flatten()
    for tag, array of tags.groupBy()
      tag.count = array.length
      percent = array.length / context.count
      percent = 0.2 if percent < 0.2
      context.tags.push
        name: tag
        percent: percent
    
    $('#feedback_edit').html @renderEditMultiple(context)
    @focusEditor()

  editNothing: ->
    $('#feedback_edit').html('')

  focusEditor: ->
    $('#feedback_edit').find('input').autocompleteTags(@tags).focus()

  removeTag: (e)->
    e.preventDefault()
    e.stopImmediatePropagation()
    $tag = $(e.target).closest('.feedback-tag')
    tag = $tag.text().replace(/\s/g, '')
    ids = @selectedIds()
    tags = [tag]
    $.destroy '/feedback/comments/tags', comment_ids: ids, tags: tags
      .success =>
        @comments.get(id).removeTags(tags) for id in ids
        @editSelected()
      .error ->
        console.log 'error', arguments

  keydownNewTag: (e)->
    if e.keyCode is KEY.RETURN
      e.preventDefault()
      e.stopImmediatePropagation()
      @addTag()
    if e.keyCode in [KEY.DOWN, KEY.UP]
      @addTag()

  addTag: ->
    $input = $('.feedback-new-tag')
    tags = $input.selectedTags()
    ids = @selectedIds()
    $.post '/feedback/comments/tags', comment_ids: ids, tags: tags
      .success =>
        @tags = _.uniq @tags.concat(tags)
        for id in ids
          comment = @comments.get(id)
          comment.addTags(tags)
          @redrawComment comment
        @editSelected()
      .error ->
        console.log 'error', arguments

  promptToImportCsv: (data)->
    $modal = $(@renderImportModal(data)).modal()
    $modal.on 'hidden', -> $(@).remove()

    addTags = @activateTagControls($modal)

    $modal.find('#import_button').click =>
      addTags()

      $modal.find('button').prop('disabled', true)
      params = $modal.find('form').serializeObject()
      $.post "#{window.location.pathname}/import", params
        .success (response)=>
          $modal.modal('hide')
          alertify.success "#{response.count} comments imported"
          tags = params["tags[]"]
          if tags
            tags = [tags] unless _.isArray(tags)
            tags = _.uniq(tags)
            $("#q").val _.map(tags, (tag)-> "##{tag}").join(" ")
          @search()
        .error ->
          console.log 'error', arguments
          $modal.find('button').prop('disabled', false)

  deleteComments: (e)->
    e.preventDefault()
    ids = @selectedIds()
    imports = _.uniq(@comments.get(id).get('import') for id in ids)
    if imports.length is 1 and imports[0]
      $modal = $(@renderDeleteImportedModal()).modal()
      $modal.on 'hidden', -> $(@).remove()
      $modal.find('#delete_selected').click =>
        $modal.modal('hide')
        @_deleteComments(comment_ids: ids)
      $modal.find('#delete_imported').click =>
        $modal.modal('hide')
        @_deleteComments(import: imports[0])
    else
      @_deleteComments(comment_ids: ids)

  _deleteComments: (params)->
    $.destroy '/feedback/comments', params
      .success (response)=>
        @selectNext()

        ids = response.ids
        alertify.success "#{ids.length} comments deleted"

        selectors = []
        for id in ids
          @comments.remove(id)
          selectors.push "#comment_#{id}"

        $(selectors.join(",")).remove()
      .error ->
        console.log 'error', arguments

  editCommentText: (e)->
    e.preventDefault() if e
    if $('.feedback-edit-comment').hasClass('edit-text')
      $('.feedback-edit-comment').removeClass('edit-text')
      $('.btn-edit').text('Edit')
    else
      $('.feedback-edit-comment').addClass('edit-text')
      $('.btn-edit').text('Cancel')

  saveCommentText: (e)->
    e.preventDefault() if e
    
    text = $('.feedback-text.edit textarea').val()
    customer = $('.feedback-customer-edit > input').val()
    comment = @comments.get @selectedId()
    comment.save(text: text, customer: customer)
      .success =>
        @redrawComment comment
        @editSelected()
        alertify.success "Comment updated"
        $('.feedback-edit-comment').removeClass('edit-text')
        $('.btn-edit').text('Edit')
      .error ->
        console.log 'error', arguments

  redrawComment: (comment)->
    $("#comment_#{comment.id}").html @renderComment(comment.toJSON())

  keydownCommentText: (e)->
    # Don't select another comment or jump to the search bar
    e.stopImmediatePropagation()

  newFeedback: (e)->
    e.preventDefault() if e
    $modal = $(@renderNewCommentModal()).modal()
    $modal.on 'hidden', -> $(@).remove()
    
    $modal.find('#new_feedback_customer').focus()
    $modal.find('.uploader').supportImages()
    
    addTags = @activateTagControls($modal)
    
    submit = =>
      addTags()
      params = $modal.find('form').serialize()
      $.post window.location.pathname, params
        .success =>
          $modal.modal('hide')
          alertify.success "Comment created"
          @search()
        .error ->
          console.log 'error', arguments
    
    $modal.find('.feedback-new-tag').keydown (e)->
      if e.keyCode is KEY.RETURN
        if e.metaKey or e.ctrlKey
          submit()
    
    $modal.find('#create_button').click => submit()

  activateTagControls: ($el)->
    $el.find('#new_feedback_tags').autocompleteTags(@tags)
    $newTag = $el.find('.feedback-new-tag')

    addTags = =>
      tags = $newTag.selectedTags()
      $tags = $el.find('.feedback-tag-list')
      for tag in tags
        $tags.append """
          <span class="feedback-tag feedback-tag-new">
            #{tag}
            <input type="hidden" name="tags[]" value="#{tag}" />
            <a class="feedback-remove-tag"><i class="fa fa-close"></i></a>
          </span>
        """
      $newTag.val('')

    $newTag.keydown (e)->
      if e.keyCode is KEY.RETURN
        unless e.metaKey or e.ctrlKey
          e.preventDefault()
          addTags()

    $el.on 'click', '.feedback-remove-tag', (e)->
      $(e.target).closest('.feedback-tag-new').remove()
      $el.find('.feedback-new-tag').focus()

    addTags


  markAsRead: (comment, callback)->
    comment.markAsRead ->
      $(".feedback-search-result.feedback-comment[data-id=\"#{comment.get('id')}\"]")
        .removeClass('feedback-comment-unread')
        .addClass('feedback-comment-read')
      callback() if callback

  markAsUnread: (comment, callback)->
    comment.markAsUnread ->
      $(".feedback-search-result.feedback-comment[data-id=\"#{comment.get('id')}\"]")
        .addClass('feedback-comment-unread')
        .removeClass('feedback-comment-read')
      callback() if callback



  toggleExtraTags: (e)->
    e.preventDefault() if e
    $a = $(e.target)
    $a.toggleClass('show-all-tags')
    $('#extra_tags').toggleClass 'collapsed', !$a.hasClass('show-all-tags')

  clickTag: (e)->
    e.preventDefault() if e
    $a = $(e.target).closest('a')
    tag = @getQuery $a.attr('href')
    $('#q').val tag
    @search()
  
  getQuery: (params)->
    @getParameterByName(params, 'q')
  
  # http://james.padolsey.com/javascript/bujs-1-getparameterbyname/
  getParameterByName: (params, name)->
    match = RegExp("[?&]#{name}=([^&]*)").exec(params)
    decodeURIComponent(match[1].replace(/\+/g, ' ')) if match



  toggleRead: (e)->
    if !$(e.target).hasClass('active')
      for comment in @selectedComments
        @markAsRead(comment)
    else
      for comment in @selectedComments
        @markAsUnread(comment)

