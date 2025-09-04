from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import LimitOffsetPagination
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from .models import Conversation, Message, MessageAttachment
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
        return (
            Conversation.objects
            .filter(members=self.request.user)
            .distinct()
            .order_by("-created_at")
        )

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

        # اجازه فقط به اعضا
        if not Conversation.objects.filter(id=conv_id, members=self.request.user).exists():
            return Message.objects.none()

        qs = Message.objects.filter(conversation_id=conv_id).order_by("id")

        after_id = self.request.query_params.get("after_id")
        if after_id:
            try:
                qs = qs.filter(id__gt=int(after_id))
            except (ValueError, TypeError):
                pass

        # اختیاری: limit دستی (کنار pagination)
        limit = self.request.query_params.get("limit")
        if limit:
            try:
                qs = qs[: int(limit)]
            except (ValueError, TypeError):
                pass

        return qs


class MessageSendView(APIView):
    """
    POST: ارسال پیام متنی + آپلود فایل (تکی/چندتا)
    بدنه JSON یا فرم/مالتی‌پارت:
      - conversation_id (الزامی)
      - text (اختیاری)
      - file=... (اختیاری، تکی)
      - files=... (اختیاری، چندتا)
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        serializer = MessageCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)

        msg = Message.objects.create(
            conversation=serializer.validated_data["conversation"],
            sender=serializer.validated_data["sender"],
            text=serializer.validated_data.get("text", "") or "",
        )

        # فایل‌ها
        files = []
        files += request.FILES.getlist("file")
        files += request.FILES.getlist("files")

        for f in files:
            MessageAttachment.objects.create(
                message=msg,
                file=f,
                content_type=getattr(f, "content_type", "") or "",
                size=getattr(f, "size", 0) or 0,
            )

        # مهم: حتماً request رو به serializer پاس بده تا URLهای فایل‌ها درست ساخته بشن
        data = MessageSerializer(msg, context={"request": request}).data
        return Response(data, status=status.HTTP_201_CREATED)
