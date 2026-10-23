MAX_SIZE = 10 * 1024 * 1024

def check_size(size):
    if size > MAX_SIZE:
        return "REJECTED"
    return "ALLOWED"

print("Exactly 10 MB:", check_size(MAX_SIZE))
print("10 MB + 1 byte:", check_size(MAX_SIZE + 1))
