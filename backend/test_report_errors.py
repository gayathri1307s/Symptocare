from services.report_service import extract_text_from_report

tests = [
    (b"not a real pdf", "test.pdf"),
    (b"not an image", "test.png"),
    (b"test", "test.txt"),
]

for data, filename in tests:
    try:
        extract_text_from_report(data, filename)
        print(filename, "ACCEPTED")
    except ValueError as e:
        print(filename, "REJECTED:", e)
