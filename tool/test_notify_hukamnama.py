import datetime as dt
import unittest

import notify_hukamnama as n

# Placeholder text only, apart from the single heading-marker words being tested.
HEADING = "HEADING ਮਹਲਾ"
OPENING = "ੴ OPENING"


def verse(text):
    return {"verse": {"unicode": text}}


class FirstLineTest(unittest.TestCase):
    def test_skips_leading_headings(self):
        shabad = {"verses": [verse(HEADING), verse(OPENING), verse("LINE ONE"), verse("LINE TWO")]}
        self.assertEqual(n.first_line(shabad), "LINE ONE")

    def test_first_line_when_no_heading(self):
        shabad = {"verses": [verse("LINE ONE"), verse("LINE TWO")]}
        self.assertEqual(n.first_line(shabad), "LINE ONE")

    def test_falls_back_to_first_line(self):
        shabad = {"verses": [verse(HEADING)]}
        self.assertEqual(n.first_line(shabad), HEADING)

    def test_ignores_empty_lines(self):
        shabad = {"verses": [verse("  "), {"verse": {}}, verse("LINE ONE")]}
        self.assertEqual(n.first_line(shabad), "LINE ONE")


class ResponseTest(unittest.TestCase):
    def test_date_and_title(self):
        body = {
            "date": {"gregorian": {"year": 2026, "month": 10, "date": 24}},
            "shabads": [{"shabadInfo": {"pageNo": 641}, "verses": [verse("LINE")]}],
        }
        self.assertEqual(n.hukam_date(body), dt.date(2026, 10, 24))
        self.assertEqual(n.title_for(n.first_shabad(body)), "Today's Hukamnama · Ang 641")

    def test_title_without_ang(self):
        self.assertEqual(n.title_for({}), "Today's Hukamnama")


if __name__ == "__main__":
    unittest.main()
