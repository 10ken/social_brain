package com.example.api

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class ExtractionContractTest {
    @Test
    fun `parses the shared camelCase extraction fixture`() {
        val result = ExtractionContract.parse(readSharedFixture("ai-extraction.valid.json"))

        assertNotNull(result)
        assertEquals("Michelle", result!!.people.single().name)
        assertEquals("2026-06-13", result.events.single().resolvedDate)
        assertEquals("Alex", result.relationships.single().personA)
    }

    @Test
    fun `rejects the shared legacy snake_case fixture`() {
        assertNull(ExtractionContract.parse(readSharedFixture("ai-extraction.invalid.json")))
    }

    private fun readSharedFixture(name: String): String {
        var directory: File? = File(System.getProperty("user.dir")).absoluteFile
        repeat(10) {
            val root = directory ?: error("Could not locate the repository root")
            val fixture = File(root, "shared/contracts/v1/fixtures/$name")
            if (fixture.isFile) return fixture.readText()
            directory = root.parentFile
        }
        error("Could not locate shared contract fixture: $name")
    }
}
