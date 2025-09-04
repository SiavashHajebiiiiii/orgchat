# backend/chat/serializers.py
from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import Conversation, Message

User = get_user_model()

# برای نمایش مختصر کاربر
class SimpleUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "username", "first_name", "last_name")

# خروجی لیست/جزییات گفتگو
class ConversationSerializer(serializers.ModelSerializer):
    members = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    members_detail = SimpleUserSerializer(source="members", many=True, read_only=True)

    class Meta:
        model = Conversation
        fields = ("id", "name", "is_group", "members", "members_detail", "created_at")

# ساخت گفتگو (DM یا گروه)
class ConversationCreateSerializer(serializers.Serializer):
    name = serializers.CharField(required=False, allow_blank=True, max_length=200)
    is_group = serializers.BooleanField(required=False, default=False)
    members = serializers.ListField(child=serializers.IntegerField(min_value=1), allow_empty=False)

    def validate(self, attrs):
        request = self.context["request"]
        is_group = attrs.get("is_group", False)
        members = list(set(attrs["members"]))  # یکتا

        if request.user.id not in members:
            members.append(request.user.id)

        if not is_group:
            if len(members) != 2:
                raise serializers.ValidationError("For DM, members must be exactly 1 other user.")
        else:
            if len(members) < 2:
                raise serializers.ValidationError("Group must include at least you and one more user.")

        # وجود کاربران
        exists = set(User.objects.filter(id__in=members).values_list("id", flat=True))
        missing = [m for m in members if m not in exists]
        if missing:
            raise serializers.ValidationError(f"User IDs not found: {missing}")

        attrs["members"] = members
        return attrs

    def create(self, validated_data):
        from django.db.models import Count

        request = self.context["request"]
        is_group = validated_data.get("is_group", False)
        members = validated_data["members"]
        name = validated_data.get("name", "")

        if not is_group:
            me, other = sorted(members)
            qs = (Conversation.objects
                  .filter(is_group=False, members=me)
                  .filter(members=other)
                  .annotate(mcount=Count("members"))
                  .filter(mcount=2))
            existing = qs.first()
            if existing:
                return existing

        conv = Conversation.objects.create(name=name or "", is_group=is_group)
        conv.members.set(members)
        return conv

# نمایش پیام
class MessageSerializer(serializers.ModelSerializer):
    sender_detail = SimpleUserSerializer(source="sender", read_only=True)

    class Meta:
        model = Message
        fields = ("id", "conversation", "sender", "sender_detail", "text", "created_at")

# ساخت پیام
class MessageCreateSerializer(serializers.Serializer):
    conversation_id = serializers.IntegerField()
    text = serializers.CharField(allow_blank=False)

    def validate(self, attrs):
        request = self.context["request"]
        try:
            conv = Conversation.objects.get(id=attrs["conversation_id"])
        except Conversation.DoesNotExist:
            raise serializers.ValidationError("Conversation not found.")

        # کاربر باید عضو گفتگو باشد
        if not conv.members.filter(id=request.user.id).exists():
            raise serializers.ValidationError("You are not a member of this conversation.")

        attrs["conversation"] = conv
        attrs["sender"] = request.user
        attrs["text"] = attrs["text"].strip()
        if not attrs["text"]:
            raise serializers.ValidationError("Text is required.")
        return attrs

