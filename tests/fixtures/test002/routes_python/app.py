from django.urls import path

urlpatterns = [
    path("users/<int:id>/", lambda request, user_id: None),
]

note = "/users/example"
