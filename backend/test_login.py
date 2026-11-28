from supabase import create_client
from database import SUPABASE_URL, SUPABASE_KEY

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

email = input("Enter your Supabase email: ")
password = input("Enter your Supabase password: ")

response = supabase.auth.sign_in_with_password({
    "email": email,
    "password": password
})

print("Login successful!")
print("Access token:")
print(response.session.access_token)