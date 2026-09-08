package com.example.secureprint.data.auth

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.delay

@RunWith(AndroidJUnit4::class)
class SessionManagerTest {

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        SessionManager.init(context)
        SessionManager.clearSession()
    }

    @After
    fun teardown() {
        SessionManager.clearSession()
    }

    @Test
    fun testSaveAndReadTokenAndRole() {
        val testToken = "test_jwt_token_123"
        val testRole = "CUSTOMER"

        SessionManager.saveSession(testToken, testRole)

        assertEquals(testToken, SessionManager.getToken())
        assertEquals(testRole, SessionManager.getRole())
    }

    @Test
    fun testClearSession() {
        SessionManager.saveSession("token", "SHOP")
        assertNotNull(SessionManager.getToken())
        
        SessionManager.clearSession()
        
        assertNull(SessionManager.getToken())
        assertNull(SessionManager.getRole())
    }

    @Test
    fun testAuthStateUpdates() {
        SessionManager.clearSession()
        assertTrue(SessionManager.authState.value is AuthState.LoggedOut)

        SessionManager.saveSession("token", "ADMIN")
        val state = SessionManager.authState.value
        assertTrue(state is AuthState.LoggedIn)
        assertEquals("ADMIN", (state as AuthState.LoggedIn).role)
    }
    @Test
    fun testForceLogoutTriggersEvent() = runBlocking {
        SessionManager.saveSession("token", "ADMIN")
        
        var eventTriggered = false
        val job = launch {
            SessionManager.logoutEvent.first()
            eventTriggered = true
        }

        SessionManager.forceLogout()
        
        // Let flow collect
        delay(100)
        
        assertTrue("Logout event should be emitted", eventTriggered)
        assertTrue(SessionManager.authState.value is AuthState.LoggedOut)
        
        job.cancel()
    }

    @Test
    fun testSessionRestorationOnInit() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        SessionManager.saveSession("restore_token", "CUSTOMER")
        
        // Re-initialize to simulate app restart
        SessionManager.init(context)
        
        assertEquals("restore_token", SessionManager.getToken())
        assertEquals("CUSTOMER", SessionManager.getRole())
        
        val state = SessionManager.authState.value
        assertTrue(state is AuthState.LoggedIn)
        assertEquals("CUSTOMER", (state as AuthState.LoggedIn).role)
    }
}
