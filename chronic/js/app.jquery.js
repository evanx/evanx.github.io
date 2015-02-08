
$(document).ready(function() {
   console.log("ready");
   if (!redirectPage()) {
      initPersona();
      $('#App-nav-login').click(navLoginPersona);
      $('#App-nav-logout').click(navLogoutPersona);
   }
});

var state = {};

function initPersona() {
   var persona = localStorage.getItem("persona");
   var loggedInUser = null;
   if (persona !== null) {
      try {
         state.persona = JSON.parse(persona);
         if (state.persona.accessToken) {
            console.log("persona", state.persona.accessToken.substring(0, 10));
            loggedInUser = state.persona.email;
            loginPersona(state.persona.accessToken);
         } else {
            logoutPersona();
         }
      } catch (e) {
         console.log(e);
      }
   } else {
      loggedOut();
   }
   navigator.id.watch({
      loggedInUser: loggedInUser,
      onlogin: function(assertion) {
         console.log("onlogin");
         loginPersona(assertion);
      },
      onlogout: function() {
         if (state.persona && state.persona.email) {
            console.log("onlogout", state.persona.email);            
         } else {
            console.warn("onlogout");
         }
      }
   });
}


function redirectPage() {
   console.log("redirectPage", window.location.origin);
   if (window.location.protocol === "https:") {
      return false;
   }
   var host = location.host;
   var index = location.host.indexOf(':');
   if (index > 0) {
      host = location.host.substring(0, index) + ':8443';
   }
   window.location = "https://" + host + location.pathname + location.search + location.hash;
   console.log(window.location);
   return true;
}

function navLoginPersona() {
   console.log("navLoginPersona");
   navigator.id.request();
}

function navLogoutPersona() {
   console.log("navLogoutPersona");
   navigator.id.logout();
   logoutPersona();
}

function logoutPersona() {
   localStorage.clear("persona");
   if (state.persona && state.persona.email) {
      $.ajax({
         type: 'POST',
         url: '/app/LogoutPersona',
         data: {
            email: state.persona.email
         },
         success: function(res, status, xhr) {
            console.log("onlogout success", res);
            loggedOut();
         },
         error: function(xhr, status, err) {
            console.log("onlogout error", err);
            loggedOut();
         }
      });
   } else {
      loggedOut();
   }
}

function loginPersona(assertion) {
   $.ajax({
      type: 'POST',
      url: '/app/LoginPersona',
      data: {
         assertion: assertion
      },
      success: function(res, status, xhr) {
         if (res.email && res.label) {
            console.log("onlogin success", res.email);
            state.persona = res;
            localStorage.setItem("persona", JSON.stringify(state.persona));
            loggedIn();
         } else {
            console.log("onlogin success invalid", res);
         }
      },
      error: function(xhr, status, err) {
         console.log("onlogin error", err);
      }
   });
}

function loggedOut() {
   state.persona = null;
   $('.App-label-username').text('');
   $('.App-view-loggedin').hide()
   $('.App-view-loggedout').removeClass('hide');
   $('.App-view-loggedout').show();   
}

function loggedIn() {
   $('.App-label-username').text(state.persona.label);
   $('.App-view-loggedout').hide()
   $('.App-view-loggedin').removeClass('hide');
   $('.App-view-loggedin').show();
   $.ajax({
      type: 'POST',
      url: '/app/GetStatus',
      data: {
      },
      success: function(res, status, xhr) {
         console.log("GetStatus success", res);
      },
      error: function(xhr, status, err) {
         console.log("GetStatus error", err);
      }
   });
}
