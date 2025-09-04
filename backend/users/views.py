from django.contrib.auth import authenticate, get_user_model
from rest_framework import generics, status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.generics import ListAPIView

from .serializers import RegisterSerializer, SimpleUserSerializer

UserModel = get_user_model()

class RegisterView(generics.CreateAPIView):
    queryset = UserModel.objects.all()
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get("username")
        password = request.data.get("password")
        user = authenticate(username=username, password=password)
        if user is not None and user.is_active:
            token, _ = Token.objects.get_or_create(user=user)
            return Response({"token": token.key}, status=status.HTTP_200_OK)
        return Response({"detail": "Invalid credentials"}, status=status.HTTP_400_BAD_REQUEST)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Token.objects.filter(user=request.user).delete()  # امن‌تر از try/except
        return Response({"success": "Logged out"}, status=status.HTTP_200_OK)


class UserListView(ListAPIView):
    serializer_class = SimpleUserSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return UserModel.objects.filter(is_active=True).order_by("id")

