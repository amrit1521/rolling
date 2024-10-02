###
# The application file bootstraps the angular app by  initializing the main module and
# creating namespaces and moduled for controllers, filters, services, and directives.
###
window.APP = APP = angular.module(
  'APP',
  [
    'APP.constants'
    'APP.controllers'
    'APP.directives'
    'APP.filters'
    'APP.templates'
    'APP.models'
    'APP.services'
    # 'ngFlow'
    'webStorageModule'
    '$strap.directives'
    'ngCookies'
    'ngDragDrop'
    'ngRoute'
    'ngTouch'
    'ui.bootstrap'
  ]
)

APP.Constants = angular.module('APP.constants', [])
APP.Controllers = angular.module('APP.controllers', [])
APP.Directives = angular.module('APP.directives', [])
APP.Filters = angular.module('APP.filters', [])
APP.Templates = angular.module('APP.templates', [])
APP.Models = angular.module('APP.models', ['ngResource'])
APP.Services = angular.module('APP.services', [])
APP.languages = [{id: "en_US", title: "English", abbreviation: "En"}, {id: "es_US", title: "Español", abbreviation: "Es"}]
APP.locale = "en_US"
APP.language = {}

APP.config(['$locationProvider', '$routeProvider', ($locationProvider, $routeProvider) ->
  $routeProvider
    .when('/admin/drawresults/:state', {templateUrl: 'templates/admin/hunts/draw_results.html'})
    .when('/admin/emails', {templateUrl: 'templates/admin/emails/index.html'})
    .when('/admin/emails/points', {templateUrl: 'templates/admin/emails/points.html'})
    .when('/admin/emails/welcome', {templateUrl: 'templates/admin/emails/welcome.html'})
    .when('/admin/emails/hunt_catalog', {templateUrl: 'templates/admin/emails/hunt_catalog.html'})
    .when('/admin/huntcatalog/:id', {templateUrl: 'templates/admin/hunt_catalog.html'})
    .when('/admin/huntcatalogs', {templateUrl: 'templates/admin/hunt_catalogs.html'})
    .when('/admin/hunts/add/:stateId', {templateUrl: 'templates/admin/hunts/edit.html'})
    .when('/admin/hunts/configuredates/:id', {templateUrl: 'templates/admin/hunts/configuredates.html'})
    .when('/admin/hunts/:id', {templateUrl: 'templates/admin/hunts/edit.html'})
    .when('/admin/filemaker', {templateUrl: 'templates/admin/upload.html'})
    .when('/admin/purchase_edit/:id', {templateUrl: 'templates/admin/purchase_edit.html'})
    .when('/admin/reports/users', {templateUrl: 'templates/admin/reports/users.html'})
    .when('/admin/reports/purchases', {templateUrl: 'templates/admin/reports/purchases.html'})
    .when('/admin/reports/commissions', {templateUrl: 'templates/admin/reports/commissions.html'})
    .when('/admin/reports/accounting', {templateUrl: 'templates/admin/reports/accounting.html'})
    .when('/admin/reports/charts', {templateUrl: 'templates/admin/reports/charts.html'})
    .when('/admin/reminder/:id', {templateUrl: 'templates/admin/reminder.html'})
    .when('/admin/reminders', {templateUrl: 'templates/admin/reminders.html'})
    .when('/admin/reminders/send/:id', {templateUrl: 'templates/admin/reminders_send.html'})
    .when('/admin/search', {templateUrl: 'templates/admin/search.html'})
    .when('/admin/servicerequests', {templateUrl: 'templates/admin/service_requests.html'})
    .when('/admin/servicerequest/:id', {templateUrl: 'templates/admin/service_request.html'})
    .when('/admin/states', {templateUrl: 'templates/admin/states.html'})
    .when('/admin/state/:id', {templateUrl: 'templates/admin/state.html'})
    .when('/admin/state/hunts/:id', {templateUrl: 'templates/admin/hunts.html'})
    .when('/admin/states/add', {templateUrl: 'templates/admin/state.html'})
    .when('/admin/billing', {templateUrl: 'templates/admin/billing.html'})
    .when('/admin/tenants', {templateUrl: 'templates/admin/tenants.html'})
    .when('/admin/tenant/new', {templateUrl: 'templates/admin/tenant.html'})
    .when('/admin/tenant/:id', {templateUrl: 'templates/admin/tenant.html'})
    .when('/admin/users/new', {templateUrl: 'templates/public/setup.html', controller: 'Setup'})
    .when('/admin/users/userimport', {templateUrl: 'templates/admin/import_users.html'})
    .when('/admin/masquerade/:id', {templateUrl: 'templates/error404.html', controller: 'AdminUserMasquerade'})
    .when('/admin/outfitter/:id', {templateUrl: 'templates/admin/outfitter.html'})
    .when('/admin/outfitters/purchases', {templateUrl: 'templates/admin/outfitters/purchases.html'})
    .when('/admin/applications', {templateUrl: 'templates/admin/applications.html'})
    .when('/admin/record_payment', {templateUrl: 'templates/admin/record_payment.html'})


    .when('/users/search', {templateUrl: 'templates/users/search.html', controller: 'UsersSearch'})

    .when('/hunts/editHunt/:stateId/:huntId/:file/:name*', {templateUrl: 'templates/hunts/editHunt.html'})

    .when('/', {templateUrl: 'templates/public/login.html'})
    .when('/about', {templateUrl: 'templates/public/about.html'})
    .when('/ssndetails', {templateUrl: 'templates/public/ssndetails.html'})


    .when('/contact', {templateUrl: 'templates/public/contact.html'})
    .when('/home', {templateUrl: 'templates/public/home.html'})
    .when('/faq', {templateUrl: 'templates/public/faq.html'})
    .when('/terms', {templateUrl: 'templates/public/terms.html'})


    .when('/fg_sites', {templateUrl: 'templates/public/fg_sites.html'})
    .when('/fg_apps', {templateUrl: 'templates/public/fg_apps.html'})
    .when('/fg_odds', {templateUrl: 'templates/public/fg_odds.html'})

    .when('/hunts/add/:stateId', {templateUrl: 'templates/authenticated/hunts/add.html'})
    .when('/hunts/application/:id', {templateUrl: 'templates/authenticated/hunts/application.html'})

    .when('/login', {templateUrl: 'templates/public/login.html'})

    .when('/memberdashboard', {templateUrl: 'templates/authenticated/dashboard_member.html'})
    .when('/repdashboard', {templateUrl: 'templates/authenticated/dashboard_rep.html'})
    .when('/repdashboard/purchases', {templateUrl: 'templates/custom/rbo/dashboard_rep_purchases.html'})
    .when('/repdashboard/users', {templateUrl: 'templates/custom/rbo/dashboard_rep_users.html'})

    .when('/dashboard', {templateUrl: 'templates/authenticated/dashboard.html'})
    .when('/dashboard/:state', {templateUrl: 'templates/authenticated/dashboard.html'})
    .when('/changepassword', {templateUrl: 'templates/authenticated/changepassword.html', controller: 'ChangePassword'})
    .when('/changeparent', {templateUrl: 'templates/authenticated/changeparent.html', controller: 'ChangeParent'})
    .when('/creditcard/:huntId', {templateUrl: 'templates/authenticated/credit_card.html'})
    .when('/profile', {templateUrl: 'templates/authenticated/profile.html', controller: 'Users'})
    .when('/huntingprofile', {templateUrl: 'templates/authenticated/huntingprofile.html', controller: 'HuntingProfile'})
    .when('/purchase_receipt/:id', {templateUrl: 'templates/authenticated/purchase_receipt.html'})
    .when('/purchases', {templateUrl: 'templates/authenticated/purchases.html'})
    .when('/huntcatalogs', {templateUrl: 'templates/public/hunt_catalogs.html'})
    .when('/huntcatalog/:id', {templateUrl: 'templates/public/hunt_catalog.html'})
    .when('/huntcatalog/purchase/:id', {templateUrl: 'templates/public/purchase.html'})

    .when('/points/:stateId', {templateUrl: 'templates/authenticated/points.html'})

    .when('/register', {templateUrl: 'templates/public/register.html'})
    .when('/notifications', {templateUrl: 'templates/users/notifications.html'})
    .when('/reminders', {templateUrl: 'templates/users/reminders.html'})
    .when('/setup', {templateUrl: 'templates/public/setup.html', controller: 'Setup'})

    # .otherwise({redirectTo: '/'})

  $locationProvider.html5Mode(false).hashPrefix('!')
])
