import os
import sys
import unittest

os.environ.setdefault("SUPABASE_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_PUBLIC_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "placeholder-anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "placeholder-service")
os.environ.setdefault("OPENAI_API_KEY", "placeholder-openai")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.services.ai_agent import _TOOLS, _matches_knowledge_query, _should_enable_tools


class TestAiInventoryKnowledge(unittest.TestCase):
    def test_project_kit_questions_enable_live_tools(self):
        self.assertTrue(_should_enable_tools(message="Where is my drivetrain project kit?"))

    def test_joined_space_questions_enable_live_tools(self):
        self.assertTrue(_should_enable_tools(message="What is in the joined space?"))

    def test_knowledge_tool_is_registered(self):
        names = {tool["function"]["name"] for tool in _TOOLS}
        self.assertIn("inventory_knowledge_search", names)

    def test_search_matches_project_kit_bom_text(self):
        row = {
            "name": "Centerstage Robot",
            "location": "Build Room",
            "notes": "goBILDA 5203-2402-0019 Yellow Jacket Motor",
        }
        self.assertTrue(_matches_knowledge_query(row, "yellow jacket"))
        self.assertTrue(_matches_knowledge_query(row, "5203-2402-0019"))

    def test_search_requires_all_query_terms(self):
        row = {"name": "Drivetrain Kit", "location": "Build Room"}
        self.assertFalse(_matches_knowledge_query(row, "drivetrain garage"))


if __name__ == "__main__":
    unittest.main()
