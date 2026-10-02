from typesafe_sdk import Choice, Noul, Score, TypeSafeClient

client = TypeSafeClient()

response = client.system_one(
    state={
        "ticket": {
            "subject": "Duplicate charge",
            "messages": [
                {"from": "customer",
                 "text": "I was charged twice for order A-104. Please refund the duplicate."},
            ],
        },
        "order": {"id": "A-104", "charges": [
            {"amount_usd": 49, "status": "captured"},
            {"amount_usd": 49, "status": "captured"},
        ]},
        "refund_policy": "Duplicate charges are eligible for a refund.",
    },
    questions={
        "department":       Choice(instructions="Which team should handle this",
                                   criteria={"billing": "Payment or subscription issues",
                                             "technical": "Bugs or integration problems",
                                             "sales": "Pricing or account questions"}),
        "frustration":      Score(instructions="How frustrated the customer appears",
                                  criteria=["Calm, just stating facts",
                                            "Frustrated but civil",
                                            "Very angry, strong language"]),
        "refund_requested": Noul(instructions="The customer is explicitly asking for a refund"),
        "policy_supports":  Noul(instructions="The stated refund policy covers this situation"),
    },
)

dept = response.answers["department"]
print(dept.choice, dept.confidence)
print(response.answers["frustration"].score)
print(response.answers["refund_requested"].noul)