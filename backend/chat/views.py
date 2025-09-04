# backend/chat/views.py
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import LimitOffsetPagination

from .models import Conversation, Message
from .serializers import (
    ConversationSerializer,
    ConversationCreateSerializer,
    MessageSerializer,
    MessageCreateSerializer,
)

class IsAuthenticated(permissions.IsAuthenticated):
    pass

class DefaultLimitOffsetPagination(LimitOffsetPagination):
    default_limit = 50
    max_limit = 200

class ConversationListCreateView(generics.ListCreateAPIView):
    """
    GET: لیست کانورسیشن‌های کاربر
    POST: ساخت کانورسیشن (DM یا گروه) — سازنده خودکار عضو می‌شود
    """
    permission_classes = [IsAuthenticated]
    pagination_class = DefaultLimitOffsetPagination

    def get_queryset(self):
        return Conversation.objects.filter(members=self.request.user).distinct().order_by("-created_at")

    def get_serializer_class(self):
        return ConversationCreateSerializer if self.request.method == "POST" else ConversationSerializer

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx["request"] = self.request
        return ctx

class MessageListView(generics.ListAPIView):
    """
    GET: پیام‌های یک کانورسیشن (فقط اگر عضو باشی)
    پارامتر after_id برای Pull اینکریمنتال
    """
    permission_classes = [IsAuthenticated]
    serializer_class = MessageSerializer
    pagination_class = DefaultLimitOffsetPagination

    def get_queryset(self):
        conv_id = self.kwargs["conversation_id"]

        # اطمینان از عضویت کاربر
        if not Conversation.objects.filter(id=conv_id, members=self.request.user).exists():
            return Message.objects.none()

        qs = Message.objects.filter(conversation_id=conv_id).order_by("id")

        after_id = self.request.query_params.get("after_id")
        if after_id:
            try:
                qs = qs.filter(id__gt=int(after_id))
            except (ValueError, TypeError):
                pass

        # اختیاری: limit دستی (در کنار pagination)
        limit = self.request.query_params.get("limit")
        if limit:
            try:
                qs = qs[: int(limit)]
            except (ValueError, TypeError):
                pass

        return qs

class MessageSendView(APIView):
    """
    POST: ارسال پیام
    بدنه: { "conversation_id": <int>, "text": "<string>" }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = MessageCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        msg = Message.objects.create(
            conversation=serializer.validated_data["conversation"],
            sender=serializer.validated_data["sender"],
            text=serializer.validated_data["text"],
        )
        return Response(MessageSerializer(msg).data, status=status.HTTP_201_CREATED)

