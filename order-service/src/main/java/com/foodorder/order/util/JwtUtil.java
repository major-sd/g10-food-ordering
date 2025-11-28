package com.foodorder.order.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;

@Component
public class JwtUtil {
    private static final String SECRET = "mySecretKeyForJWTTokenGeneration12345678901234567890";

    public Claims parseToken(String token) {
        SecretKey key = Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8));
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public String getRole(Claims claims) {
        return claims.get("role", String.class);
    }

    public Long getUserId(Claims claims) {
        return claims.get("userId", Long.class);
    }
}

