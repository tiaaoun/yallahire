require("dotenv").config();

const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const OpenAI = require("openai");

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const BLOCKED_CATEGORY_REASONS = {
  "harassment/threatening": "Threatening content is not allowed.",
  "hate/threatening": "Threatening hate content is not allowed.",
  "self-harm": "Self-harm content is not allowed.",
  "self-harm/intent": "Self-harm content is not allowed.",
  "self-harm/instructions": "Self-harm content is not allowed.",
  "sexual/minors": "Sexual content involving minors is not allowed.",
  "violence/graphic": "Graphic violent content is not allowed.",
  "illicit/violent": "Violent illegal content is not allowed.",
};

const BLOCKED_UNSAFE_SERVICE_PATTERN =
  /\b(prostitute|prostitution|escort|sexual|sex work|nude|explicit)\b/i;

function getFlaggedReason(scores = {}) {
  const entries = Object.entries(scores);
  if (!entries.length) return "This content may violate safety rules.";

  entries.sort((a, b) => (b[1] || 0) - (a[1] || 0));
  const [topCategory] = entries[0];

  const reasonMap = {
    harassment: "This content may contain harassment.",
    "harassment/threatening": "This content may contain threats.",
    hate: "This content may contain hate speech.",
    "hate/threatening": "This content may contain threatening hate speech.",
    illicit: "This content may involve illegal activity.",
    "illicit/violent": "This content may involve violent illegal activity.",
    "self-harm": "This content may involve self-harm.",
    "self-harm/intent": "This content may involve self-harm.",
    "self-harm/instructions": "This content may involve self-harm.",
    sexual: "This content may be sexually explicit.",
    "sexual/minors": "This content is not allowed.",
    violence: "This content may contain violence.",
    "violence/graphic": "This content may contain graphic violence.",
  };

  return reasonMap[topCategory] || "This content may violate safety rules.";
}

function mapModerationResult(result = {}) {
  const categories = result.categories || {};
  const scores = result.category_scores || {};
  const harassmentScore = Number(scores.harassment) || 0;
  const threateningHarassmentScore =
    Number(scores["harassment/threatening"]) || 0;
  const hateScore = Number(scores.hate) || 0;

  for (const [category, reason] of Object.entries(BLOCKED_CATEGORY_REASONS)) {
    if (categories[category] === true) {
      return {
        status: "blocked",
        reason,
      };
    }
  }

  if (result.flagged === true) {
    return {
      status: "flagged",
      reason: getFlaggedReason(scores),
    };
  }

  if (
    harassmentScore >= 0.18 ||
    threateningHarassmentScore >= 0.12 ||
    hateScore >= 0.15
  ) {
    return {
      status: "flagged",
      reason: getFlaggedReason(scores),
    };
  }

  const maxScore = Math.max(
      0,
      ...Object.values(scores).map((value) => Number(value) || 0),
  );

  if (maxScore >= 0.28) {
    return {
      status: "flagged",
      reason: getFlaggedReason(scores),
    };
  }

  return {
    status: "safe",
    reason: "Content is safe.",
  };
}

exports.improvePost = onRequest({ cors: true, invoker: "public" }, async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed" });
    }

    const { title, description, postType } = req.body || {};
    const originalDescription = (description || "").toString().trim();

    logger.info("improvePost request received", {
      title: (title || "").toString(),
      description: originalDescription,
      postType: (postType || "").toString(),
    });

    if (!originalDescription) {
      return res.status(400).json({
        error: "Please provide a description.",
      });
    }

    const mode =
      postType === "service"
        ? `
You are improving a marketplace post written by a person offering their service.

Rules for service posts:
- Write in first person when natural, like "I can help with..." or "I am available..."
- Sound warm, confident, and realistic
- Keep it short: maximum 2 short sentences
- Do not sound like a company
- Do not use "we" or "our"
`
        : `
You are improving a marketplace post written by a person hiring someone.

Rules for hiring posts:
- Write from the hirer's perspective, like "Looking for..." or "Need..."
- Sound clear, respectful, and realistic
- Keep it short: maximum 2 short sentences
- Do not sound like a company
- Do not use "we" or "our"
`;

    const prompt = `
You are improving only the DESCRIPTION of a marketplace post for an app called YallaHire.

General rules:
- Do NOT rewrite or return the title
- Use the title only as context
- Improve only the description
- Rewrite it so it sounds clearer, more natural, and more polished
- Improve wording, grammar, clarity, and flow
- Keep the meaning the same
- Do not invent details that were not provided
- Do not add experience requirements, schedules, or qualifications unless they were mentioned
- Keep it concise and natural
- If the original wording is weak, awkward, repetitive, or unclear, rewrite it properly instead of repeating it
- Do not copy the original wording unless it is already strong and cannot be meaningfully improved
- Return only the improved description text, with no JSON and no extra formatting

${mode}

Title for context: ${title || ""}
Original description: ${originalDescription}
`;

    const response = await openai.responses.create({
      model: "gpt-4o-mini",
      input: prompt,
    });

    const rawOutputText = (response.output_text || "").toString();
    logger.info("improvePost raw output_text", {
      outputText: rawOutputText,
    });

    const improvedDescription = rawOutputText.trim();

    if (!improvedDescription) {
      logger.warn("improvePost returned empty output_text, using fallback", {
        title: (title || "").toString(),
      });

      return res.json({
        improvedDescription: originalDescription,
      });
    }

    return res.json({
      improvedDescription,
    });
  } catch (error) {
    logger.error(error);

    if (error.status === 429) {
      return res.status(429).json({
        error: "OpenAI quota exceeded or billing is not active yet.",
      });
    }

    return res.status(500).json({
      error: error.message || "Something went wrong",
    });
  }
});

exports.moderatePostText = onRequest({ cors: true, invoker: "public" }, async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed" });
    }

    if (!process.env.OPENAI_API_KEY) {
      logger.error("Missing OPENAI_API_KEY");
      return res.status(500).json({ error: "Moderation is not configured." });
    }

    const { title, description } = req.body || {};
    const combinedText = [title, description]
        .map((value) => (value ?? "").toString().trim())
        .filter(Boolean)
        .join("\n\n");

    if (!combinedText) {
      return res.status(400).json({ error: "No content to moderate." });
    }

    if (BLOCKED_UNSAFE_SERVICE_PATTERN.test(combinedText)) {
      return res.json({
        status: "blocked",
        reason: "Adult or sexual services are not allowed on YallaHire.",
      });
    }

    const moderation = await openai.moderations.create({
      model: "omni-moderation-latest",
      input: combinedText,
    });

    const result =
  moderation.results?.[0] ||
  moderation.data?.[0] ||
  {};

const mapped = mapModerationResult({
  flagged: result.flagged ?? false,
  categories: result.categories ?? {},
  category_scores: result.category_scores ?? {},
});

    return res.json(mapped);
  } catch (error) {
    logger.error(error);

    if (error.status === 429) {
      return res.status(429).json({
        error: "OpenAI quota exceeded or billing is not active yet.",
      });
    }

    return res.status(500).json({ error: "Something went wrong" });
  }
});
