from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import Conversation, Message, MessageAttachment
from users.serializers import SimpleUserSerializer

User = get_user_model()


class MessageAttachmentSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = MessageAttachment
        fields = ["id", "file", "file_url", "content_type", "size", "uploaded_at"]
        read_only_fields = ["id", "content_type", "size", "uploaded_at"]

    def get_file_url(self, obj):
        req = self.context.get("request")
        return req.build_absolute_uri(obj.file.url) if req else obj.file.url


class MessageSerializer(serializers.ModelSerializer):
    sender_detail = SimpleUserSerializer(source="sender", read_only=True)
    attachments = MessageAttachmentSerializer(many=True, read_only=True)

    class Meta:
        model = Message
        fields = [
            "id",
            "conversation",
            "sender",
            "sender_detail",
            "text",
            "created_at",
            "attachments",
        ]


class MessageCreateSerializer(serializers.Serializer):
    conversation_id = serializers.IntegerField()
    text = serializers.CharField(allow_blank=True, required=False, default="")

    def validate(self, attrs):
        request = self.context["request"]
        try:
            conv = Conversation.objects.get(
                id=attrs["conversation_id"], members=request.user
            )
        except Conversation.DoesNotExist:
            raise serializers.ValidationError(
                "Conversation not found or you're not a member."
            )
        attrs["conversation"] = conv
        attrs["sender"] = request.user
        return attrs


class ConversationSerializer(serializers.ModelSerializer):
    members = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    members_detail = SimpleUserSerializer(source="members", many=True, read_only=True)

    class Meta:
        model = Conversation
        fields = ["id", "name", "is_group", "members", "members_detail", "created_at"]


class ConversationCreateSerializer(serializers.Serializer):
    name = serializers.CharField(required=False, allow_blank=True, max_length=200)
    is_group = serializers.BooleanField(required=False, default=False)
    members = serializers.ListField(
        child=serializers.IntegerField(min_value=1), allow_empty=False
    )

    def validate(self, attrs):
        request = self.context["request"]
        is_group = attrs.get("is_group", False)
        members = list(set(attrs["members"]))

        if request.user.id not in members:
            members.append(request.user.id)

        if not is_group:
            if len(members) != 2:
                raise serializers.ValidationError(
                    "For DM, members must be exactly 1 other user."
                )
        else:
            if len(members) < 2:
                raise serializers.ValidationError(
                    "Group must include at least you and one more user."
                )

        attrs["members"] = members
        return attrs

    def create(self, validated_data):
        from django.db.models import Count

        is_group = validated_data.get("is_group", False)
        members = validated_data["members"]
        name = validated_data.get("name", "")

        if not is_group:
            me, other = sorted(members)
            qs = (
                Conversation.objects.filter(is_group=False, members=me)
                .filter(members=other)
                .annotate(mcount=Count("members"))
                .filter(mcount=2)
            )
            existing = qs.first()
            if existing:
                return existing

        conv = Conversation.objects.create(name=name or "", is_group=is_group)
        conv.members.set(members)
        return conv

