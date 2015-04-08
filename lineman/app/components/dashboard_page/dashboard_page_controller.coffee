angular.module('loomioApp').controller 'DashboardPageController', ($rootScope, Records, CurrentUser, LoadingService) ->
  $rootScope.$broadcast('currentComponent', 'dashboardPage')
  $rootScope.$broadcast('setTitle', 'Dashboard')

  @loaded =
    sort_by_date:
      show_all: 0
      show_unread: 0
      show_proposals: 0
    sort_by_group:
      show_all: 0
      show_unread: 0
      show_proposals: 0
  @perPage =
    sort_by_date: 25
    sort_by_group: 10
  @groupThreadCounts =
    hidden:    0
    collapsed: 5
    expanded:  10

  @sort   = -> CurrentUser.dashboardSort
  @filter = -> CurrentUser.dashboardFilter

  @loadParams = ->
    filter: @filter()
    per:    @perPage[@sort()]
    from:   @loadedCount()

  @loadedCount = (group) =>
    if group
      @groupThreadCounts[group.dashboardStatus or 'collapsed']
    else
      @loaded[@sort()][@filter()]

  @loadMore = (options = {}) =>
    @loaded[@sort()][@filter()] = @loadedCount() + @perPage[@sort()]
    switch @sort()
      when 'sort_by_date'  then Records.discussions.fetchInboxByDate(@loadParams())
      when 'sort_by_group' then Records.discussions.fetchInboxByGroup(@loadParams())
  LoadingService.applyLoadingFunction @, 'loadMore'

  @changePreferences = (options = {}) =>
    CurrentUser.updateFromJSON(options)
    CurrentUser.save()
    @loadMore() if @loadedCount() == 0

  @dashboardOptions = (group) =>
    unmuted:   true
    unread:    @filter() == 'show_unread'
    proposals: @filter() == 'show_proposals'
    groupId:   (group.id if group)

  @dashboardDiscussionReaders = (group) =>
    _.pluck Records.discussionReaders.forDashboard(@dashboardOptions(group)).data(), 'id'

  @dashboardDiscussions = (group) =>
    Records.discussions.findByDiscussionIds(@dashboardDiscussionReaders(group))
                       .simplesort('lastActivityAt', true)
                       .limit(@loadedCount(group))
                       .data()

  @dashboardGroups = ->
    _.filter CurrentUser.groups(), (group) -> group.isParent()

  timeframe = (options = {}) ->
    today = moment().startOf 'day'
    (discussion) ->
      discussion.lastInboxActivity()
                .isBetween(today.clone().subtract(options['fromCount'] or 1, options['from']),
                           today.clone().subtract(options['toCount'] or 1, options['to']))

  inTimeframe = (fn) =>
    =>
      @loadedCount() > 0 and _.find @dashboardDiscussions(), (discussion) => fn(discussion)

  @today     = timeframe(from: 'second', toCount: -10, to: 'year')
  @yesterday = timeframe(from: 'day', to: 'second')
  @thisWeek  = timeframe(from: 'week', to: 'day')
  @thisMonth = timeframe(from: 'month', to: 'week')
  @older     = timeframe(fromCount: 3, from: 'month', to: 'month')

  @anyToday     = inTimeframe(@today)
  @anyYesterday = inTimeframe(@yesterday)
  @anyThisWeek  = inTimeframe(@thisWeek)
  @anyThisMonth = inTimeframe(@thisMonth)
  @anyOlder     = inTimeframe(@older)

  @groupName    = (group) -> group.name
  @anyThisGroup = (group) => @dashboardDiscussions(group).length > 0
  @canExpand    = (group) =>
    @loadedCount(group) < _.min [@dashboardDiscussionReaders(group).length, @groupThreadCounts.expanded]

  Records.votes.fetchMyRecentVotes()
  @loadMore()

  return
