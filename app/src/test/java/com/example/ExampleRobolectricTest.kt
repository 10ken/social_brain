package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.data.*
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class ExampleRobolectricTest {

    @Test
    fun `read string from context`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val appName = context.getString(R.string.app_name)
        assertEquals("Social Memory", appName)
    }

    @Test
    fun `crm entity mapping matches specifications`() {
        // Assert that we can model a robust person with location and nickname details
        val person = Person(
            id = 1,
            fullName = "Sarah Jenkins",
            nickname = "Sare",
            location = "New York",
            notes = "Met Sarah at paddling conference, interested in climate policy."
        )

        assertEquals("Sarah Jenkins", person.fullName)
        assertEquals("Sare", person.nickname)
        assertEquals("New York", person.location)
    }

    @Test
    fun `event timeline mapping matches specifications`() {
        // Validate social events models can be created safely with specified properties
        val event = SocialEvent(
            id = 10,
            title = "Weekend Paddle BBQ",
            location = "Hanlan's Point Beach",
            startTime = 1718049600000L, // Sunday 2:00 PM
            groupId = 5,
            confidenceState = "confirmed"
        )

        assertEquals("Weekend Paddle BBQ", event.title)
        assertEquals("Hanlan's Point Beach", event.location)
        assertEquals("confirmed", event.confidenceState)
    }
}
