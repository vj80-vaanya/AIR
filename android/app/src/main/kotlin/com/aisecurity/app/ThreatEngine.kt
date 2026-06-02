package com.aisecurity.app

import android.content.Context
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.InputStreamReader
import kotlin.math.exp

/**
 * Native Kotlin threat-analysis engine — full port of the Dart SecurityEngine.
 *
 * Tier 1 : Text normalisation + pattern matching  (instant, no ML)
 * Tier 2 : ONNX BERT-tiny inference               (ambiguous messages only)
 *
 * Runs entirely in native code so background threat detection works even
 * when the Flutter/Dart isolate is paused or the app is fully killed.
 */
object ThreatEngine {

    private const val TAG     = "ThreatEngine"
    private const val SEQ_LEN = 64
    private const val CLS_ID  = 101L
    private const val SEP_ID  = 102L
    private const val PAD_ID  = 0L
    private const val UNK_ID  = 100L

    // Flutter bundles assets under flutter_assets/ inside the APK
    private const val VOCAB_PATH = "flutter_assets/assets/data/vocab.txt"
    private const val MODEL_PATH = "flutter_assets/assets/models/text_classifier.onnx"

    @Volatile private var vocab:   Map<String, Int>? = null
    @Volatile private var session: OrtSession?       = null
    @Volatile private var env:     OrtEnvironment?   = null
    @Volatile var       mlReady    = false
    @Volatile var       blockThreshold = 75

    // ── Initialisation ────────────────────────────────────────────────────────

    fun init(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Load vocabulary (30 522 lines of bert-tiny vocab)
                val lines = BufferedReader(
                    InputStreamReader(context.assets.open(VOCAB_PATH))
                ).readLines()
                vocab = buildMap { lines.forEachIndexed { i, l -> if (l.isNotEmpty()) put(l, i) } }

                // Load ONNX session
                env = OrtEnvironment.getEnvironment()
                val opts = OrtSession.SessionOptions().apply {
                    setIntraOpNumThreads(2)
                    setInterOpNumThreads(1)
                }
                val modelBytes = context.assets.open(MODEL_PATH).readBytes()
                session = env!!.createSession(modelBytes, opts)
                mlReady = true
                Log.d(TAG, "ML engine ready — vocab=${vocab!!.size} tokens")
            } catch (e: Exception) {
                Log.e(TAG, "ML init failed (pattern-only mode): ${e.message}")
                mlReady = false
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun analyzeText(text: String): ThreatResult {
        val normalized = TextNormalizerKt.normalize(text)
        val pattern    = PatternMatcherKt.analyze(normalized)
        val tone       = BehavioralAnalyzerKt.analyzeTone(text)
        val socialEng  = FinancialSafetyInterceptorKt.analyzeSocialEngineering(text)

        var urlRisk = 0
        val urlMatch = Regex("""(https?://|www\.)\S+""").find(text)
        if (urlMatch != null) urlRisk = UrlSafetyEngineKt.analyzeUrl(urlMatch.value)

        val tier1 = pattern.score + socialEng

        var combinedScore: Double
        var mlScore = 0.0
        var mlUsed  = false

        // Tier 2: only run when tier 1 is ambiguous (20–84 range)
        if (mlReady && tier1 in 21..84) {
            val ml = runMlInference(text)
            if (ml != null) { mlScore = ml.toDouble(); mlUsed = true }
        }

        combinedScore = if (mlUsed)
            pattern.score * 0.3 + mlScore * 100 * 0.4 + socialEng * 0.2 + tone * 0.1
        else
            pattern.score * 0.5 + socialEng * 0.3 + tone * 0.2

        if (urlRisk > 50)                combinedScore += 25.0
        if (pattern.hasSuspiciousEntities) combinedScore += 10.0

        val clamped  = combinedScore.toInt().coerceIn(0, 100)
        val category = resolveCategory(pattern, mlScore, mlUsed, socialEng)

        return ThreatResult(
            riskScore    = clamped,
            category     = category,
            reason       = buildReason(pattern, mlScore, mlUsed, socialEng, urlRisk),
            shouldBlock  = clamped >= blockThreshold,
            confidence   = if (mlUsed) 0.92f else 0.80f,
        )
    }

    // ── ONNX inference ────────────────────────────────────────────────────────

    private fun runMlInference(text: String): Float? {
        val v = vocab   ?: return null
        val s = session ?: return null
        val e = env     ?: return null
        return try {
            val ids  = tokenize(text.lowercase(), v)
            val idsA = Array(1) { LongArray(SEQ_LEN) { i -> ids[i] } }
            val atA  = Array(1) { LongArray(SEQ_LEN) { i -> if (ids[i] != PAD_ID) 1L else 0L } }
            val ttA  = Array(1) { LongArray(SEQ_LEN) { 0L } }

            val tIds  = OnnxTensor.createTensor(e, idsA)
            val tAttn = OnnxTensor.createTensor(e, atA)
            val tType = OnnxTensor.createTensor(e, ttA)

            val result  = s.run(mapOf("input_ids" to tIds, "attention_mask" to tAttn, "token_type_ids" to tType))
            val rawValue = result[0].value
            tIds.close(); tAttn.close(); tType.close()

            if (rawValue == null) return null
            @Suppress("UNCHECKED_CAST")
            val logits = (rawValue as Array<FloatArray>)[0]
            val maxL = maxOf(logits[0], logits[1])
            val e0   = exp((logits[0] - maxL).toDouble())
            val e1   = exp((logits[1] - maxL).toDouble())
            (e1 / (e0 + e1)).toFloat()
        } catch (ex: Exception) {
            Log.e(TAG, "ML inference error: ${ex.message}")
            null
        }
    }

    // ── WordPiece tokeniser ───────────────────────────────────────────────────

    private fun tokenize(text: String, vocab: Map<String, Int>): LongArray {
        val ids = mutableListOf(CLS_ID)
        for (word in text.split(Regex("""[\s.,!?;:()\[\]{}<>/\\@#${'$'}%^&*+=|~`]+"""))) {
            if (word.isEmpty()) continue
            ids.addAll(wordpiece(word, vocab))
            if (ids.size >= SEQ_LEN - 1) break
        }
        ids.add(SEP_ID)
        while (ids.size < SEQ_LEN) ids.add(PAD_ID)
        return LongArray(SEQ_LEN) { ids[it] }
    }

    private fun wordpiece(word: String, vocab: Map<String, Int>): List<Long> {
        vocab[word]?.let { return listOf(it.toLong()) }
        val out   = mutableListOf<Long>()
        var start = 0
        while (start < word.length) {
            var end   = word.length
            var found: Long? = null
            while (start < end) {
                val sub = if (start == 0) word.substring(start, end)
                          else "##${word.substring(start, end)}"
                vocab[sub]?.let { found = it.toLong() }
                if (found != null) break
                end--
            }
            if (found == null) return listOf(UNK_ID)
            out.add(found!!)
            start = end
        }
        return out
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun resolveCategory(p: PatternResultKt, mlScore: Double, mlUsed: Boolean, socialEng: Int) = when {
        socialEng > 50            -> "FINANCIAL_FRAUD_ATTEMPT"
        p.category != "SAFE"      -> p.category
        mlUsed && mlScore >= 0.75 -> "AI_DETECTED_SPAM"
        else                      -> "SAFE"
    }

    private fun buildReason(p: PatternResultKt, mlScore: Double, mlUsed: Boolean, socialEng: Int, urlRisk: Int) =
        when (p.category) {
            "DIGITAL_ARREST"  -> "CRITICAL: Digital Arrest scam. This is illegal — police never arrest via video call."
            "INVESTMENT_SCAM" -> "WARNING: Investment trap. No legitimate scheme guarantees high returns."
            "ACCOUNT_HIJACK"  -> "CRITICAL: WhatsApp hijacking attempt. Never rent your account or scan QR for money."
            else -> listOfNotNull(
                if (socialEng > 0)  "financial pressure tactics detected"   else null,
                if (urlRisk  > 40)  "suspicious URL detected"               else null,
                if (p.score  > 0)   "matches known scam pattern"            else null,
                if (mlUsed)         "AI confidence ${(mlScore * 100).toInt()}%" else null,
            ).joinToString(" + ").ifEmpty { "No threats detected" }
        }
}

// ── Result types ──────────────────────────────────────────────────────────────

data class ThreatResult(
    val riskScore:   Int,
    val category:    String,
    val reason:      String,
    val shouldBlock: Boolean,
    val confidence:  Float,
) {
    companion object {
        val SAFE = ThreatResult(0, "SAFE", "No threats detected", false, 0.95f)
    }
}

data class PatternResultKt(
    val score: Int,
    val category: String,
    val hasSuspiciousEntities: Boolean = false,
)

// ── Text Normalizer ───────────────────────────────────────────────────────────

object TextNormalizerKt {
    private val SUBS = mapOf('0' to 'o', '1' to 'i', '3' to 'e', '4' to 'a',
                              '5' to 's', '8' to 'b', '@' to 'a', '!' to 'i', '$' to 's')

    fun normalize(text: String): String {
        var s = text.lowercase().replace(Regex("""[.\-_\s*#@]"""), "")
        SUBS.forEach { (k, v) -> s = s.replace(k, v) }
        return s.trim()
    }
}

// ── Pattern Matcher ───────────────────────────────────────────────────────────

object PatternMatcherKt {
    private val UPI_RE = Regex("""[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}""")
    private val URL_RE = Regex("""(https?://|www\.)\S+""")

    private data class Rule(val kw: String, val cat: String, val w: Int)

    private val RULES = listOf(
        Rule("your account has been suspended","BANKING_FRAUD",90), Rule("kyc update","BANKING_FRAUD",88),
        Rule("pan card","BANKING_FRAUD",75),                        Rule("aadhaar update","BANKING_FRAUD",85),
        Rule("your sim will be blocked","BANKING_FRAUD",92),        Rule("electricity bill pending","BILL_SCAM",88),
        Rule("bijli bill","BILL_SCAM",90),
        Rule("congratulations you have won","LOTTERY",95),          Rule("mubarak ho","LOTTERY",90),
        Rule("inam jeeta hai","LOTTERY",92),                        Rule("kbc lottery","LOTTERY",96),
        Rule("lucky draw","LOTTERY",85),
        Rule("immediately","URGENCY",30), Rule("turant","URGENCY",40), Rule("aaj hi","URGENCY",35),
        Rule("last date","URGENCY",45),   Rule("within 24 hours","URGENCY",50),
        Rule("digital arrest","DIGITAL_ARREST",98),                 Rule("cbi","DIGITAL_ARREST",85),
        Rule("narcotics","DIGITAL_ARREST",88),                      Rule("mumbai police","DIGITAL_ARREST",85),
        Rule("illegal parcel","DIGITAL_ARREST",90),                 Rule("video call verification","DIGITAL_ARREST",92),
        Rule("supreme court","DIGITAL_ARREST",80),                  Rule("arrest warrant","DIGITAL_ARREST",95),
        Rule("insider tips","INVESTMENT_SCAM",85),                  Rule("guaranteed returns","INVESTMENT_SCAM",90),
        Rule("stock market profit","INVESTMENT_SCAM",75),           Rule("trading group","INVESTMENT_SCAM",70),
        Rule("crypto investment","INVESTMENT_SCAM",82),             Rule("earn daily","INVESTMENT_SCAM",65),
        Rule("rent your whatsapp","ACCOUNT_HIJACK",95),             Rule("scan qr to earn","ACCOUNT_HIJACK",92),
        Rule("whatsapp account renting","ACCOUNT_HIJACK",98),       Rule("automatic earnings","ACCOUNT_HIJACK",80),
    )

    fun analyze(text: String): PatternResultKt {
        val lower = text.lowercase()
        var score = 0; var cat = "SAFE"; var urgency = 0
        for (r in RULES) {
            if (!lower.contains(r.kw)) continue
            if (r.cat == "URGENCY") urgency += r.w
            else if (r.w > score)  { score = r.w; cat = r.cat }
        }
        val hasUpi = UPI_RE.containsMatchIn(text)
        val hasUrl = URL_RE.containsMatchIn(text)
        if (score > 0) {
            if (hasUpi) score += 15; if (hasUrl) score += 10; if (urgency > 40) score += 15
        }
        if (hasUpi && (cat == "BILL_SCAM" || cat == "LOTTERY")) score = (score + 25).coerceAtMost(100)
        return PatternResultKt(score.coerceIn(0,100), cat, hasUpi || hasUrl)
    }
}

// ── Behavioral Analyzer ───────────────────────────────────────────────────────

object BehavioralAnalyzerKt {
    private val URGENCY    = listOf("immediately","urgent","now","today","24 hours","blocked","suspended","turant","aaj hi","jaldi","band ho jayega","khatam")
    private val AUTHORITY  = listOf("police","court","bank","official","trai","rbi","income tax","department","government","officer","cbi","narcotics","ed","investigation","supreme court","warrant","arrest")

    fun analyzeTone(text: String): Int {
        val l = text.lowercase()
        var s = URGENCY.count { l.contains(it) } * 15 + AUTHORITY.count { l.contains(it) } * 10
        if (text == text.uppercase() && text.length > 10) s += 20
        return s.coerceIn(0, 100)
    }
}

// ── Financial Safety Interceptor ──────────────────────────────────────────────

object FinancialSafetyInterceptorKt {
    fun analyzeSocialEngineering(text: String): Int {
        val l = text.lowercase()
        var r = 0
        if (l.contains("receive") && (l.contains("pin") || l.contains("upi"))) r += 40
        if (l.contains("scan")    && l.contains("qr"))                          r += 30
        if ((l.contains("limit")  || l.contains("expire") || l.contains("block")) &&
            (l.contains("bank")   || l.contains("card")))                       r += 25
        return r.coerceIn(0, 100)
    }
}

// ── URL Safety Engine ─────────────────────────────────────────────────────────

object UrlSafetyEngineKt {
    private val BRANDS     = listOf("sbi","hdfc","icici","axis","paytm","amazon","flipkart")
    private val SUSPICIOUS = listOf("verify","update","secure","login","account","kyc","support")
    private val SHORTENERS = listOf("bit.ly","t.co","tinyurl.com","is.gd","goo.gl")
    private val IP_RE      = Regex("""\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}""")

    fun analyzeUrl(url: String): Int {
        var r = 0; val l = url.lowercase()
        if (url.contains("xn--"))        r += 50
        if (IP_RE.containsMatchIn(url))  r += 40
        for (b in BRANDS) {
            if (!l.contains(b)) continue
            if (!l.contains(".co.in") && !l.contains(".com") && !l.contains(".in")) r += 30
            for (kw in SUSPICIOUS) if (l.contains(kw)) r += 20
        }
        for (s in SHORTENERS) if (l.contains(s)) r += 15
        return r.coerceIn(0, 100)
    }
}
