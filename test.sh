#!/bin/bash
set -e -E

GEMINI_API_KEY="AIzaSyBIqqKTyMD3-i9eQbVFRGYxxgmUJcf84_o"
MODEL_ID="gemini-3-flash-preview"
GENERATE_CONTENT_API="streamGenerateContent"

cat << EOF > request.json
{
    "contents": [
      {
        "role": "user",
        "parts": [
          {
            "inlineData": {
              "mimeType": "text/xml",
              "data": "aGV5"
            }
          },
          {
            "text": "hey"
          }
        ]
      }
    ],
   
}
EOF

curl \
-X POST \
-H "Content-Type: application/json" \
"https://generativelanguage.googleapis.com/v1beta/models/${MODEL_ID}:${GENERATE_CONTENT_API}?key=${GEMINI_API_KEY}" -d '@request.json'



