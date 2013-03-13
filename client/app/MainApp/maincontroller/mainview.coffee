class MainView extends KDView

  viewAppended:->

    @mc = @getSingleton 'mainController'

    @addHeader()
    @createMainPanels()
    @createMainTabView()
    @createSideBar()
    @listenWindowResize()

  addBook:-> @addSubView new BookView

  setViewState:(state)->

    switch state
      when 'hideTabs'
        @contentPanel.setClass 'no-shadow'
        @mainTabView.hideHandleContainer()
        @sidebar.hideFinderPanel()
      when 'application'
        @contentPanel.unsetClass 'no-shadow'
        @mainTabView.showHandleContainer()
        @sidebar.showFinderPanel()
      else
        @contentPanel.unsetClass 'no-shadow'
        @mainTabView.showHandleContainer()
        @sidebar.hideFinderPanel()

  removeLoader:->
    $loadingScreen = $(".main-loading").eq(0)
    {winWidth,winHeight} = @getSingleton "windowController"
    $loadingScreen.css
      marginTop : -winHeight
      opacity   : 0
    @utils.wait 601, =>
      $loadingScreen.remove()
      $('body').removeClass 'loading'

  createMainPanels:->

    @addSubView @panelWrapper = new KDView
      tagName  : "section"

    @panelWrapper.addSubView @sidebarPanel = new KDView
      domId    : "sidebar-panel"

    @panelWrapper.addSubView @contentPanel = new KDView
      domId    : "content-panel"
      cssClass : "transition"
      bind     : "webkitTransitionEnd" #TODO: Cross browser support

    @contentPanel.on "ViewResized", (rest...)=> @emit "ContentPanelResized", rest...

    @registerSingleton "contentPanel", @contentPanel, yes
    @registerSingleton "sidebarPanel", @sidebarPanel, yes

    @contentPanel.on "webkitTransitionEnd", (e) =>
      @emit "mainViewTransitionEnd", e

  addHeader:->

    @addSubView @header = new KDView
      tagName : "header"

    @header.addSubView @logo = new KDCustomHTMLView
      tagName   : "a"
      domId     : "koding-logo"
      # cssClass  : "hidden"
      attributes:
        href    : "#"
      click     : (event)=>
        return if @userEnteredFromGroup()

        event.stopPropagation()
        event.preventDefault()
        KD.getSingleton('router').handleRoute null

  createMainTabView:->

    @mainTabHandleHolder = new MainTabHandleHolder
      domId    : "main-tab-handle-holder"
      cssClass : "kdtabhandlecontainer"
      delegate : @

    getFrontAppManifest = ->
      appManager = KD.getSingleton "appManager"
      appController = KD.getSingleton "kodingAppsController"
      frontApp = appManager.getFrontApp()
      frontAppName = name for name, instances of appManager.appControllers when frontApp in instances
      appController.constructor.manifests?[frontAppName]

    @mainSettingsMenuButton = new KDButtonView
      domId    : "main-settings-menu"
      cssClass : "kdsettingsmenucontainer transparent"
      iconOnly : yes
      iconClass: "dot"
      callback : ->
        appManifest = getFrontAppManifest()
        if appManifest?.menu
          appManifest.menu.forEach (item, index)->
            item.callback = (contextmenu)->
              mainView = KD.getSingleton "mainView"
              view = mainView.mainTabView.activePane?.mainView
              item.eventName or= item.title
              view?.emit "menu.#{item.eventName}", item.eventName, item, contextmenu

          offset = @$().offset()
          contextMenu = new JContextMenu
              event       : event
              delegate    : @
              x           : offset.left - 150
              y           : offset.top + 20
              arrow       :
                placement : "top"
                margin    : -5
            , appManifest.menu
    @mainSettingsMenuButton.hide()

    @mainTabView = new MainTabView
      domId              : "main-tab-view"
      listenToFinder     : yes
      delegate           : @
      slidingPanes       : no
      tabHandleContainer : @mainTabHandleHolder
    ,null

    @mainTabView.on "PaneDidShow", => KD.utils.wait 10, =>
      appManifest = getFrontAppManifest()
      @mainSettingsMenuButton[if appManifest?.menu then "show" else "hide"]()

    mainController = @getSingleton('mainController')
    mainController.popupController = new VideoPopupController

    mainController.monitorController = new MonitorController

    @videoButton = new KDButtonView
      cssClass : "video-popup-button"
      icon : yes
      title : "Video"
      callback :=>
        unless @popupList.$().hasClass "hidden"
          @videoButton.unsetClass "active"
          @popupList.hide()
        else
          @videoButton.setClass "active"
          @popupList.show()

    @videoButton.hide()

    @popupList = new VideoPopupList
      cssClass      : "hidden"
      type          : "videos"
      itemClass     : VideoPopupListItem
      delegate      : @
    , {}

    @mainTabView.on "AllPanesClosed", ->
      @getSingleton('router').handleRoute "/Activity"

    @contentPanel.addSubView @mainTabView
    @contentPanel.addSubView @mainTabHandleHolder
    @contentPanel.addSubView @mainSettingsMenuButton
    @contentPanel.addSubView @videoButton
    @contentPanel.addSubView @popupList

    getSticky = =>
      @getSingleton('windowController')?.stickyNotification
    getStatus = =>
      KD.remote.api.JSystemStatus.getCurrentSystemStatus (err,systemStatus)=>
        if err
          if err.message is 'none_scheduled'
            getSticky()?.emit 'restartCanceled'
          else
            log 'current system status:',err
        else
          systemStatus.on 'restartCanceled', =>
            getSticky()?.emit 'restartCanceled'
          new GlobalNotification
            targetDate  : systemStatus.scheduledAt
            title       : systemStatus.title
            content     : systemStatus.content
            type        : systemStatus.type

    # sticky = @getSingleton('windowController')?.stickyNotification
    @utils.defer => getStatus()

    KD.remote.api.JSystemStatus.on 'restartScheduled', (systemStatus)=>
      sticky = @getSingleton('windowController')?.stickyNotification

      if systemStatus.status isnt 'active'
        getSticky()?.emit 'restartCanceled'
      else
        systemStatus.on 'restartCanceled', =>
          getSticky()?.emit 'restartCanceled'
        new GlobalNotification
          targetDate : systemStatus.scheduledAt
          title      : systemStatus.title
          content    : systemStatus.content
          type       : systemStatus.type

  createSideBar:->

    @sidebar = new Sidebar domId : "sidebar", delegate : @
    @emit "SidebarCreated", @sidebar
    @sidebarPanel.addSubView @sidebar

  changeHomeLayout:(isLoggedIn)->

  userEnteredFromGroup:-> KD.config.groupEntryPoint?

  userEnteredFromProfile:-> KD.config.profileEntryPoint?

  switchGroupState:(isLoggedIn)->

    {groupEntryPoint} = KD.config

    # loginLink = new GroupsLandingPageButton {groupEntryPoint}, {}

    if isLoggedIn and groupEntryPoint?
      KD.whoami().fetchGroupRoles groupEntryPoint, (err, roles)->
        if err then console.warn err
        else if roles.length
          loginLink.setState { isMember: yes, roles }
        else
          {JMembershipPolicy} = KD.remote.api
          JMembershipPolicy.byGroupSlug groupEntryPoint,
            (err, policy)->
              if err then console.warn err
              else if policy?
                loginLink.setState {
                  isMember        : no
                  approvalEnabled : policy.approvalEnabled
                }
              else
                loginLink.setState {
                  isMember        : no
                  isPublic        : yes
                }
    else
      @utils.defer -> loginLink.setState { isLoggedIn: no }

    loginLink.appendToSelector '.group-login-buttons'

  addGroupViews:->

    return if @groupViewsAdded
    @groupViewsAdded = yes

    groupLandingView = new KDView
      lazyDomId : 'group-landing'

    groupLandingView.listenWindowResize()
    groupLandingView._windowDidResize = =>
      groupLandingView.setHeight window.innerHeight
      groupContentView.setHeight window.innerHeight - groupTitleView.getHeight()

    groupContentWrapperView = new KDView
      lazyDomId : 'group-content-wrapper'
      cssClass : 'slideable'

    groupTitleView = new KDView
      lazyDomId : 'group-title'

    groupContentView = new KDView
      lazyDomId : 'group-loading-content'

    groupSplitView = new SplitViewWithOlderSiblings
      lazyDomId : 'group-splitview'
      parent : groupContentWrapperView

    groupPersonalWrapperView = new KDView
      lazyDomId : 'group-personal-wrapper'
      cssClass : 'slideable'
      click :(event)=>
        unless event.target.tagName is 'A'
          @mc.loginScreen.unsetClass 'landed'

    groupLogoView = new KDView
      lazyDomId: 'group-koding-logo'
      click :=>
        groupPersonalWrapperView.setClass 'slide-down'
        groupContentWrapperView.setClass 'slide-down'
        groupLogoView.setClass 'top'

        groupLandingView.setClass 'group-fading'
        @utils.wait 1100, => groupLandingView.setClass 'group-hidden'

    groupLogoView.$().css
      top: groupLandingView.getHeight()-42

    @utils.wait => groupLogoView.setClass 'animate'

  addProfileViews:->

    log 'adding views'

    return if @profileViewsAdded
    @profileViewsAdded = yes

    profileLandingView = new KDView
      lazyDomId : 'profile-landing'

    profileLandingView.listenWindowResize()
    profileLandingView._windowDidResize = =>
      profileLandingView.setHeight window.innerHeight
      profileContentView.setHeight window.innerHeight-profileTitleView.getHeight()

    profileContentWrapperView = new KDView
      lazyDomId : 'profile-content-wrapper'
      cssClass : 'slideable'

    profileTitleView = new KDView
      lazyDomId : 'profile-title'

    profileShowMoreView = new KDView
      lazyDomId : 'profile-show-more-wrapper'
      cssClass : 'hidden'


    profileShowMoreButton = new KDButtonView
      lazyDomId : 'profile-show-more-button'
      title :'Show more'
      callback:=>
        @emit 'ShowMoreButtonClicked'
        profileShowMoreView.hide()
        profileShowMoreView.setHeight 0
        profileLandingView._windowDidResize()

    profileContentView = new KDListView
      lazyDomId : 'profile-content'
      itemClass : StaticBlogPostListItem
    , {}

    if profileContentView.$().attr('data-count') > 0
      profileShowMoreView.show()

    profileSplitView = new SplitViewWithOlderSiblings
      lazyDomId : 'profile-splitview'
      parent : profileContentWrapperView

    profilePersonalWrapperView = new KDView
      lazyDomId : 'profile-personal-wrapper'
      cssClass : 'slideable'

    profileLogoView = new KDView
      lazyDomId: 'profile-koding-logo'
      click :=>
        profilePersonalWrapperView.setClass 'slide-down'
        profileContentWrapperView.setClass 'slide-down'
        profileLogoView.setClass 'top'

        profileLandingView.setClass 'profile-fading'
        @utils.wait 1100, => profileLandingView.setClass 'profile-hidden'

    profileLogoView.$().css
      top: profileLandingView.getHeight()-42

    profileUser = null
    @utils.wait => profileLogoView.setClass 'animate'

    KD.remote.cacheable profileLandingView.$().attr('data-profile'), (err, user, name)=>

      unless err
        profileUser = user

        if user.getId() is KD.whoami().getId()

          profileAdminMessageView = new KDView
            lazyDomId : 'profile-admin-message'

          showPage = user.profile.staticPage?.show

          profileAdminMessageView.addSubView disableLink = new CustomLinkView
            partial : "#{if showPage is yes then 'Disable' else 'Enable'} this Public Page"
            cssClass : 'message-disable'
            click : (event)=>
              event?.stopPropagation()
              event?.preventDefault()

              if user.profile.staticPage?.show is yes
                modal =  new KDModalView
                  cssClass : 'disable-static-page-modal'
                  title : 'Do you really want to disable your Public Page?'
                  content : """
                    <div class="modalformline">
                      <p>Disabling this feature will disable other people
                      from publicly viewing your profile. You will still be
                      able to access the page yourself.</p>
                      <p>Do you want to continue?</p>
                    </div>
                    """
                  buttons :
                    "Disable the Public Page" :
                      cssClass : 'modal-clean-red'
                      callback :=>
                        modal.destroy()
                        user.setStaticPageVisibility no, (err,res)=>
                          if err then log err
                          disableLink.updatePartial 'Enable this Public Page'
                    Cancel :
                      cssClass : 'modal-cancel'
                      callback :=>
                        modal.destroy()
              else
                user.setStaticPageVisibility yes, (err,res)=>
                  if err then log err
                  disableLink.updatePartial 'Disable this Public Page'

    @on 'ShowMoreButtonClicked', =>
      if profileUser
        KD.remote.api.JBlogPost.some {originId : user.getId()}, {limit:5,sort:{'meta.createdAt':-1}}, (err,blogs)=>
          log user
          if err
            log err

          else
            profileContentListController = new KDListViewController
              view : profileContentView
              startWithLazyLoader : yes
            , blogs

            profileContentView.$('.content-item').remove()

            profileContentView.on 'ItemWasAdded', (instance, index)->
              instance.viewAppended()

            profileContentListController.instantiateListItems blogs

  decorateLoginState:(isLoggedIn = no)->
    log @userEnteredFromGroup(), @userEnteredFromProfile()
    if @userEnteredFromGroup()
      @addGroupViews()
      # @switchGroupState isLoggedIn
    else if @userEnteredFromProfile()
      @addProfileViews()

    if isLoggedIn
      $('body').removeClass "login"
      $('body').addClass "loggedIn"

      new LandingPageNavLink
        title : 'Logout'
        link  : '/Logout'

      # Workaround for Develop Tab
      if "Develop" isnt @getSingleton("router")?.getCurrentPath()
        @contentPanel.setClass "social"

      @mainTabView.showHandleContainer()

    else
      $('body').addClass "login"
      $('body').removeClass "loggedIn"

      new LandingPageNavLink
        title  : 'Login'
        action : 'login'

      @contentPanel.unsetClass "social"
      @mainTabView.hideHandleContainer()

    @changeHomeLayout isLoggedIn
    @utils.wait 300, => @notifyResizeListeners()

  _windowDidResize:->

    {winHeight} = @getSingleton "windowController"
    @panelWrapper.setHeight winHeight - 51
